/**
 * @description Endpoint Apex REST para la recepción, verificación criptográfica (HMAC-SHA256),
 *              auditoría e idempotencia de eventos de Stripe Checkout (US-13, US-16, US-17, M3).
 */
@RestResource(urlMapping='/stripe/webhook/*')
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CognitiveComplexity, PMD.CyclomaticComplexity, PMD.NcssCount, PMD.AvoidDeeplyNestedIfStmts, PMD.UnusedLocalVariable')
global without sharing class StripeWebhookService {

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

        // Extracción case-insensitive del header Stripe-Signature
        String sigHeader = null;
        if (req != null && req.headers != null) {
            for (String headerKey : req.headers.keySet()) {
                if ('stripe-signature'.equalsIgnoreCase(headerKey)) {
                    sigHeader = req.headers.get(headerKey);
                    break;
                }
            }
        }

        // Recuperación segura del secreto sin exponer credenciales en código (M3)
        Stripe_Config__c config = Stripe_Config__c.getOrgDefaults();
        String webhookSecret = (config != null) ? config.Webhook_Secret__c : null;

        // Parseo preliminar seguro para identificar el evento incluso en fallos de validación
        Map<String, Object> root = null;
        try {
            if (String.isNotBlank(rawBody)) {
                root = (Map<String, Object>) JSON.deserializeUntyped(rawBody);
            }
        } catch (Exception ex) {
            root = null;
        }

        // Verificación de firma criptográfica HMAC-SHA256 (US-17 AC1/AC3)
        if (!verificarFirmaHmac(rawBody, sigHeader, webhookSecret)) {
            String evtId = null;
            if (root != null && root.containsKey('id')) {
                evtId = String.valueOf(root.get('id'));
            }

            if (String.isNotBlank(evtId)) {
                List<Aviso_Pasarela__c> colisiones = [
                    SELECT Id FROM Aviso_Pasarela__c WHERE Stripe_Event_Id__c = :evtId LIMIT 1
                ];
                if (!colisiones.isEmpty()) {
                    evtId = evtId + '_INVALID_' + Datetime.now().getTime();
                }
            } else {
                evtId = 'SIG_INVALID_' + Datetime.now().getTime();
            }

            Aviso_Pasarela__c avisoRechazado = new Aviso_Pasarela__c(
                Stripe_Event_Id__c = evtId,
                Estado_Aviso__c = 'Rechazado',
                Motivo_Rechazo__c = 'Firma criptográfica HMAC-SHA256 inválida o ausente',
                Fecha_Recepcion__c = System.now()
            );
            insert avisoRechazado;

            res.statusCode = 400;
            res.responseBody = Blob.valueOf('{"error":"Firma criptográfica HMAC-SHA256 inválida o ausente"}');
            return;
        }

        if (root == null) {
            Aviso_Pasarela__c avisoPayloadInvalido = new Aviso_Pasarela__c(
                Stripe_Event_Id__c = 'JSON_INVALID_' + Datetime.now().getTime(),
                Estado_Aviso__c = 'Rechazado',
                Motivo_Rechazo__c = 'El payload recibido no contiene un JSON válido',
                Fecha_Recepcion__c = System.now()
            );
            insert avisoPayloadInvalido;

            res.statusCode = 400;
            res.responseBody = Blob.valueOf('{"error":"Payload JSON no estructurado"}');
            return;
        }

        String eventId = root.containsKey('id') ? String.valueOf(root.get('id')) : ('EVT_UNKNOWN_' + Datetime.now().getTime());
        String eventType = root.containsKey('type') ? String.valueOf(root.get('type')) : '';

        // Control de Idempotencia: Verificar si el evento evt_... ya fue recibido previamente (US-17 AC2)
        List<Aviso_Pasarela__c> avisosPrevios = [
            SELECT Id, Donacion__c, Estado_Aviso__c
            FROM Aviso_Pasarela__c
            WHERE Stripe_Event_Id__c = :eventId
            LIMIT 1
        ];

        if (!avisosPrevios.isEmpty()) {
            Aviso_Pasarela__c avisoDuplicado = new Aviso_Pasarela__c(
                Stripe_Event_Id__c = eventId + '_DUP_' + Datetime.now().getTime(),
                Estado_Aviso__c = 'Duplicado Ignorado',
                Motivo_Rechazo__c = 'Evento duplicado ya procesado previamente (' + eventId + ')',
                Fecha_Recepcion__c = System.now(),
                Donacion__c = avisosPrevios[0].Donacion__c
            );
            insert avisoDuplicado;

            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"status":"Evento duplicado ignorado con éxito"}');
            return;
        }

        // Extracción de datos de la sesión de Stripe Checkout
        Map<String, Object> dataMap = (Map<String, Object>) root.get('data');
        Map<String, Object> sessionObj = (dataMap != null) ? (Map<String, Object>) dataMap.get('object') : null;

        String clientRefId = (sessionObj != null && sessionObj.containsKey('client_reference_id'))
            ? String.valueOf(sessionObj.get('client_reference_id'))
            : null;
        String sessionId = (sessionObj != null && sessionObj.containsKey('id'))
            ? String.valueOf(sessionObj.get('id'))
            : null;

        String donacionMetaId = null;
        if (sessionObj != null && sessionObj.containsKey('metadata')) {
            Map<String, Object> metadata = (Map<String, Object>) sessionObj.get('metadata');
            if (metadata != null && metadata.containsKey('donacion_id')) {
                donacionMetaId = String.valueOf(metadata.get('donacion_id'));
            }
        }

        // Búsqueda del registro Donacion__c por Id o por Stripe_Session_Id__c (US-16 AC3)
        Id donacionIdValido = null;
        String idCandidato = String.isNotBlank(clientRefId) ? clientRefId : donacionMetaId;
        if (String.isNotBlank(idCandidato)) {
            try {
                Id parsedId = (Id) idCandidato;
                if (parsedId.getSobjectType() == Donacion__c.SObjectType) {
                    donacionIdValido = parsedId;
                }
            } catch (Exception e) {
                donacionIdValido = null;
            }
        }

        List<Donacion__c> donaciones = new List<Donacion__c>();
        if (donacionIdValido != null) {
            donaciones = [
                SELECT Id, Name, Estado__c, Tipo_Confirmacion__c, Stripe_Session_Id__c
                FROM Donacion__c
                WHERE Id = :donacionIdValido
                LIMIT 1
            ];
        }

        if (donaciones.isEmpty() && String.isNotBlank(sessionId)) {
            donaciones = [
                SELECT Id, Name, Estado__c, Tipo_Confirmacion__c, Stripe_Session_Id__c
                FROM Donacion__c
                WHERE Stripe_Session_Id__c = :sessionId
                LIMIT 1
            ];
        }

        // Caso: Donación no encontrada (US-16 AC3)
        if (donaciones.isEmpty()) {
            Aviso_Pasarela__c avisoNoEncontrada = new Aviso_Pasarela__c(
                Stripe_Event_Id__c = eventId,
                Estado_Aviso__c = 'Rechazado',
                Motivo_Rechazo__c = 'Donación no encontrada para la referencia recibida (Ref: ' + idCandidato + ', Session: ' + sessionId + ')',
                Fecha_Recepcion__c = System.now()
            );
            insert avisoNoEncontrada;

            res.statusCode = 400;
            res.responseBody = Blob.valueOf('{"error":"Donación no encontrada"}');
            return;
        }

        Donacion__c don = donaciones[0];

        // Caso: Donación ya se encontraba en estado Pagada (US-17 AC2)
        if (don.Estado__c == 'Pagada') {
            Aviso_Pasarela__c avisoYaPagada = new Aviso_Pasarela__c(
                Stripe_Event_Id__c = eventId,
                Estado_Aviso__c = 'Duplicado Ignorado',
                Motivo_Rechazo__c = 'La donación ya se encontraba en estado Pagada',
                Fecha_Recepcion__c = System.now(),
                Donacion__c = don.Id
            );
            insert avisoYaPagada;

            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"status":"La donación ya se encontraba confirmada como Pagada"}');
            return;
        }

        // Caso: Conciliación automática exitosa (US-16 AC1/AC2)
        don.Estado__c = 'Pagada';
        don.Tipo_Confirmacion__c = 'Automática';
        if (String.isNotBlank(sessionId) && String.isBlank(don.Stripe_Session_Id__c)) {
            don.Stripe_Session_Id__c = sessionId;
        }
        update don;

        Aviso_Pasarela__c avisoProcesado = new Aviso_Pasarela__c(
            Stripe_Event_Id__c = eventId,
            Estado_Aviso__c = 'Procesado',
            Fecha_Recepcion__c = System.now(),
            Donacion__c = don.Id
        );
        insert avisoProcesado;

        res.statusCode = 200;
        res.responseBody = Blob.valueOf('{"status":"Donación conciliada y procesada exitosamente"}');
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
