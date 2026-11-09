/**
 * @description Endpoint Apex REST para la recepción, verificación criptográfica (HMAC-SHA256),
 *              auditoría e idempotencia de eventos de Stripe Checkout (US-13, US-16, US-17, M3).
 *
 *              Reglas de procesamiento:
 *              - Firma inválida, ausente o con timestamp fuera de tolerancia (5 min): Rechazado, HTTP 400.
 *              - Evento ya Procesado o Ignorado con el mismo Id: Duplicado Ignorado, HTTP 200.
 *              - checkout.session.completed con payment_status = paid, o
 *                checkout.session.async_payment_succeeded: la donación pasa a Pagada (si el monto coincide).
 *              - checkout.session.expired: la donación Pendiente pasa a Expirada.
 *              - Cualquier otro evento: Ignorado, sin cambiar donaciones.
 *              - Error inesperado: rollback, aviso con estado Error y HTTP 500 para que Stripe reintente.
 *              Las donaciones se buscan por Referencia_Publica__c (client_reference_id o metadata[referencia])
 *              y, en su defecto, por Stripe_Session_Id__c. Nunca por el Id del registro.
 */
@RestResource(urlMapping='/stripe/webhook/*')
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CognitiveComplexity, PMD.CyclomaticComplexity, PMD.ExcessiveParameterList')
global without sharing class StripeWebhookService {

    @TestVisible
    private static final Integer TOLERANCIA_SEGUNDOS = 300;

    @TestVisible
    private static Boolean forzarErrorInesperado = false;

    private static final String EVT_COMPLETADO = 'checkout.session.completed';
    private static final String EVT_PAGO_ASINCRONO = 'checkout.session.async_payment_succeeded';
    private static final String EVT_EXPIRADO = 'checkout.session.expired';

    private class ErrorInesperadoException extends Exception {}

    /**
     * @description Resultado del procesamiento de un evento: estado del aviso, motivo y HTTP.
     */
    private class Resultado {
        String estadoAviso;
        String motivo;
        Integer httpStatus;
        Id donacionId;

        Resultado(String estadoAviso, String motivo, Integer httpStatus, Id donacionId) {
            this.estadoAviso = estadoAviso;
            this.motivo = motivo;
            this.httpStatus = httpStatus;
            this.donacionId = donacionId;
        }
    }

    /**
     * @description Procesa la solicitud POST enviada por Stripe al webhook.
     */
    @HttpPost
    global static void procesarEvento() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        if (res == null) {
            res = new RestResponse();
            RestContext.response = res;
        }

        String rawBody = (req != null && req.requestBody != null) ? req.requestBody.toString() : '';
        String sigHeader = obtenerHeaderFirma(req);
        Stripe_Config__c config = Stripe_Config__c.getOrgDefaults();
        String webhookSecret = (config != null) ? config.Webhook_Secret__c : null;

        Map<String, Object> root = parsearJson(rawBody);
        String eventId = (root != null && root.get('id') != null) ? String.valueOf(root.get('id')) : null;
        String eventType = (root != null && root.get('type') != null) ? String.valueOf(root.get('type')) : null;

        // US-17 AC1/AC3/AC4: firma HMAC y antigüedad del timestamp
        String motivoFirma = validarFirma(rawBody, sigHeader, webhookSecret, System.now().getTime() / 1000);
        if (motivoFirma != null) {
            responder(res, registrar(eventId, eventType, new Resultado('Rechazado', motivoFirma, 400, null)));
            return;
        }

        if (root == null) {
            responder(res, registrar(null, null, new Resultado('Rechazado', 'El payload recibido no contiene un JSON válido', 400, null)));
            return;
        }

        // US-17 AC2/AC5: solo un evento ya Procesado o Ignorado cuenta como duplicado
        if (String.isNotBlank(eventId)) {
            List<Aviso_Pasarela__c> previos = [
                SELECT Id, Donacion__c FROM Aviso_Pasarela__c
                WHERE Stripe_Event_Id__c = :eventId AND Estado_Aviso__c IN ('Procesado', 'Ignorado')
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (!previos.isEmpty()) {
                responder(res, registrar(eventId, eventType, new Resultado('Duplicado Ignorado',
                    'Evento ya procesado previamente (' + eventId + ')', 200, previos[0].Donacion__c)));
                return;
            }
        }

        Savepoint sp = Database.setSavepoint();
        Resultado resultado;
        try {
            resultado = procesar(eventType, root);
        } catch (Exception ex) {
            Database.rollback(sp);
            resultado = new Resultado('Error', 'Error inesperado: ' + ex.getMessage(), 500, null);
        }
        responder(res, registrar(eventId, eventType, resultado));
    }

    /**
     * @description Aplica la regla de negocio según el tipo de evento (US-16 AC1–AC4).
     */
    private static Resultado procesar(String eventType, Map<String, Object> root) {
        if (Test.isRunningTest() && forzarErrorInesperado) {
            throw new ErrorInesperadoException('Error simulado en prueba');
        }

        Map<String, Object> sesion = obtenerSesion(root);
        Boolean esPago = (eventType == EVT_PAGO_ASINCRONO)
            || (eventType == EVT_COMPLETADO && 'paid'.equals(valor(sesion, 'payment_status')));
        Boolean esExpiracion = (eventType == EVT_EXPIRADO);

        if (eventType == EVT_COMPLETADO && !esPago) {
            return new Resultado('Ignorado', 'Sesión completada sin pago confirmado (payment_status distinto de paid)', 200, null);
        }
        if (!esPago && !esExpiracion) {
            return new Resultado('Ignorado', 'Tipo de evento no utilizado: ' + eventType, 200, null);
        }

        Donacion__c don = buscarDonacion(sesion);
        if (don == null) {
            return new Resultado('Rechazado', 'Donación no encontrada para la referencia recibida (Ref: '
                + valor(sesion, 'client_reference_id') + ', Session: ' + valor(sesion, 'id') + ')', 400, null);
        }

        return esPago ? aplicarPago(don, sesion) : aplicarExpiracion(don);
    }

    private static Resultado aplicarPago(Donacion__c don, Map<String, Object> sesion) {
        if (don.Estado__c == 'Pagada') {
            return new Resultado('Duplicado Ignorado', 'La donación ya se encontraba en estado Pagada', 200, don.Id);
        }

        // US-16 AC4: el monto cobrado y la moneda deben coincidir con la donación
        Decimal esperado = (don.Monto__c * 100).setScale(0, System.RoundingMode.HALF_UP);
        Decimal recibido = aDecimal(sesion.get('amount_total'));
        String moneda = valor(sesion, 'currency');
        if (recibido == null || recibido != esperado || moneda == null || !moneda.equalsIgnoreCase('mxn')) {
            return new Resultado('Rechazado', 'El monto o la moneda no coinciden con la donación (esperado '
                + esperado + ' mxn, recibido ' + recibido + ' ' + moneda + ')', 200, don.Id);
        }

        don.Estado__c = 'Pagada';
        don.Tipo_Confirmacion__c = 'Automática';
        don.Fecha_Pago__c = System.now();
        String sessionId = valor(sesion, 'id');
        if (String.isNotBlank(sessionId) && String.isBlank(don.Stripe_Session_Id__c)) {
            don.Stripe_Session_Id__c = sessionId;
        }
        update as system don;
        return new Resultado('Procesado', null, 200, don.Id);
    }

    private static Resultado aplicarExpiracion(Donacion__c don) {
        if (don.Estado__c != 'Pendiente') {
            return new Resultado('Ignorado', 'Sesión expirada para una donación en estado ' + don.Estado__c, 200, don.Id);
        }
        don.Estado__c = 'Expirada';
        update as system don;
        return new Resultado('Procesado', null, 200, don.Id);
    }

    /**
     * @description Busca la donación por referencia pública y, si no hay, por Id de sesión de Stripe.
     *              Bloquea el registro (FOR UPDATE) para evitar dobles confirmaciones concurrentes.
     */
    private static Donacion__c buscarDonacion(Map<String, Object> sesion) {
        if (sesion == null) {
            return null;
        }
        String referencia = valor(sesion, 'client_reference_id');
        Object metadata = sesion.get('metadata');
        if (String.isBlank(referencia) && metadata instanceof Map<String, Object>) {
            Object ref = ((Map<String, Object>) metadata).get('referencia');
            referencia = ref == null ? null : String.valueOf(ref);
        }
        String sessionId = valor(sesion, 'id');

        List<Donacion__c> encontradas = new List<Donacion__c>();
        if (String.isNotBlank(referencia)) {
            encontradas = [
                SELECT Id, Estado__c, Monto__c, Tipo_Confirmacion__c, Stripe_Session_Id__c
                FROM Donacion__c WHERE Referencia_Publica__c = :referencia WITH SYSTEM_MODE LIMIT 1 FOR UPDATE
            ];
        }
        if (encontradas.isEmpty() && String.isNotBlank(sessionId)) {
            encontradas = [
                SELECT Id, Estado__c, Monto__c, Tipo_Confirmacion__c, Stripe_Session_Id__c
                FROM Donacion__c WHERE Stripe_Session_Id__c = :sessionId WITH SYSTEM_MODE LIMIT 1 FOR UPDATE
            ];
        }
        return encontradas.isEmpty() ? null : encontradas[0];
    }

    private static Resultado registrar(String eventId, String eventType, Resultado r) {
        Aviso_Pasarela__c aviso = new Aviso_Pasarela__c(
            Stripe_Event_Id__c = String.isNotBlank(eventId) ? eventId.abbreviate(255) : 'SIN_ID_' + System.now().getTime(),
            Tipo_Evento__c = eventType == null ? null : eventType.abbreviate(100),
            Estado_Aviso__c = r.estadoAviso,
            Motivo_Rechazo__c = r.motivo == null ? null : r.motivo.abbreviate(255),
            Fecha_Recepcion__c = System.now(),
            Donacion__c = r.donacionId
        );
        insert as system aviso;
        return r;
    }

    private static void responder(RestResponse res, Resultado r) {
        res.statusCode = r.httpStatus;
        res.addHeader('Content-Type', 'application/json');
        Map<String, Object> cuerpo = new Map<String, Object>{ 'estado' => r.estadoAviso };
        if (r.httpStatus >= 400 && r.motivo != null) {
            cuerpo.put('error', r.motivo);
        }
        res.responseBody = Blob.valueOf(JSON.serialize(cuerpo));
    }

    private static String obtenerHeaderFirma(RestRequest req) {
        if (req == null || req.headers == null) {
            return null;
        }
        for (String headerKey : req.headers.keySet()) {
            if ('stripe-signature'.equalsIgnoreCase(headerKey)) {
                return req.headers.get(headerKey);
            }
        }
        return null;
    }

    private static Map<String, Object> parsearJson(String rawBody) {
        if (String.isBlank(rawBody)) {
            return null;
        }
        try {
            Object parsed = JSON.deserializeUntyped(rawBody);
            return (parsed instanceof Map<String, Object>) ? (Map<String, Object>) parsed : null;
        } catch (Exception ex) {
            return null;
        }
    }

    private static Map<String, Object> obtenerSesion(Map<String, Object> root) {
        Object data = root.get('data');
        if (!(data instanceof Map<String, Object>)) {
            return null;
        }
        Object objeto = ((Map<String, Object>) data).get('object');
        return (objeto instanceof Map<String, Object>) ? (Map<String, Object>) objeto : null;
    }

    private static Decimal aDecimal(Object valorCrudo) {
        if (valorCrudo == null) {
            return null;
        }
        try {
            return Decimal.valueOf(String.valueOf(valorCrudo));
        } catch (Exception ex) {
            return null;
        }
    }

    private static String valor(Map<String, Object> mapa, String clave) {
        if (mapa == null || mapa.get(clave) == null) {
            return null;
        }
        return String.valueOf(mapa.get(clave));
    }

    /**
     * @description Valida la firma del webhook: HMAC-SHA256 sobre "timestamp.payload" y antigüedad
     *              del timestamp dentro de la tolerancia (US-17 AC1, AC3, AC4).
     * @param rawBody Cuerpo completo de la solicitud.
     * @param sigHeader Valor del header Stripe-Signature.
     * @param webhookSecret Secreto del webhook guardado en Stripe_Config__c.
     * @param ahoraSegundos Hora actual en segundos Unix (parámetro para poder probarlo).
     * @return null si la firma es válida; si no, el motivo del rechazo.
     */
    @TestVisible
    private static String validarFirma(String rawBody, String sigHeader, String webhookSecret, Long ahoraSegundos) {
        if (String.isBlank(rawBody) || String.isBlank(sigHeader) || String.isBlank(webhookSecret)) {
            return 'Firma criptográfica HMAC-SHA256 inválida o ausente';
        }
        if (!verificarFirmaHmac(rawBody, sigHeader, webhookSecret)) {
            return 'Firma criptográfica HMAC-SHA256 inválida o ausente';
        }
        String timestamp = null;
        for (String item : sigHeader.split(',')) {
            String elemento = item.trim();
            if (elemento.startsWith('t=')) {
                timestamp = elemento.substring(2);
            }
        }
        Long ts;
        try {
            ts = Long.valueOf(timestamp);
        } catch (Exception ex) {
            return 'Timestamp de la firma inválido';
        }
        if (Math.abs(ahoraSegundos - ts) > TOLERANCIA_SEGUNDOS) {
            return 'Firma fuera de la tolerancia de 5 minutos (posible reenvío)';
        }
        return null;
    }

    /**
     * @description Valida criptográficamente la firma del webhook de Stripe usando HMAC-SHA256 (US-17 AC1).
     * @param rawBody Cuerpo completo en texto plano de la solicitud HTTP.
     * @param sigHeader Valor del header 'Stripe-Signature'.
     * @param webhookSecret Clave secreta para validación del webhook de Stripe.
     * @return true si alguna firma v1 coincide con el HMAC calculado; false en caso contrario.
     */
    @TestVisible
    private static Boolean verificarFirmaHmac(String rawBody, String sigHeader, String webhookSecret) {
        if (String.isBlank(rawBody) || String.isBlank(sigHeader) || String.isBlank(webhookSecret)) {
            return false;
        }

        String timestamp = null;
        List<String> firmasV1 = new List<String>();
        for (String item : sigHeader.split(',')) {
            String elemento = item.trim();
            if (elemento.startsWith('t=')) {
                timestamp = elemento.substring(2);
            } else if (elemento.startsWith('v1=')) {
                firmasV1.add(elemento.substring(3));
            }
        }

        if (String.isBlank(timestamp) || firmasV1.isEmpty()) {
            return false;
        }

        try {
            String cargaFirmada = timestamp + '.' + rawBody;
            Blob hmac = Crypto.generateMac('hmacSHA256', Blob.valueOf(cargaFirmada), Blob.valueOf(webhookSecret));
            String firmaEsperada = EncodingUtil.convertToHex(hmac);
            for (String f1 : firmasV1) {
                if (firmaEsperada.equalsIgnoreCase(f1)) {
                    return true;
                }
            }
        } catch (Exception ex) {
            return false;
        }
        return false;
    }
}
