/**
 * @description Controlador público del portal de donaciones (US-01 a US-06, US-14).
 *              Lo llama el usuario invitado del sitio de Experience Cloud.
 *
 *              Seguridad (M2):
 *              - Es "without sharing" porque el perfil invitado NO tiene permisos de objeto sobre
 *                Donacion__c ni Campana__c. Por eso el control de acceso está aquí: solo se devuelven
 *                DTOs con campos públicos y ningún método recibe ni devuelve el Id de una donación.
 *              - El navegador y Stripe solo conocen Referencia_Publica__c (UUID opaco).
 *              - Las consultas usan WITH SYSTEM_MODE y el insert "as system": en el contexto del invitado
 *                Salesforce aplica la visibilidad del usuario incluso en Apex, y el invitado no debe tener
 *                permisos de campo sobre datos privados. El filtro de qué se expone vive en este controlador.
 *              Seguridad (M3): la llave de Stripe solo se lee de Stripe_Config__c en el servidor.
 *
 *              Flujo de pago en UNA transacción: validar → callout a Stripe → insertar la donación
 *              Pendiente → devolver solo la URL de Checkout. Si Stripe falla, no se inserta nada.
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ExcessivePublicCount, PMD.CognitiveComplexity, PMD.CyclomaticComplexity')
public without sharing class DonationPublicController {

    @TestVisible
    private static final String STRIPE_ENDPOINT = 'https://api.stripe.com/v1/checkout/sessions';
    @TestVisible
    private static final Decimal MONTO_MINIMO = 10;
    private static final Integer EXPIRACION_SEGUNDOS = 3600;
    private static final Integer MAX_DONANTES_MURO = 2000;
    private static final Set<String> MODALIDADES = new Set<String>{ 'Anónima', 'Con crédito', 'Con factura' };
    private static final Pattern PATRON_CORREO = Pattern.compile('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');

    private static final String MSG_GENERICO = 'No pudimos iniciar tu donación. Intenta de nuevo en unos minutos.';
    private static final String MSG_CERRADA = 'Esta campaña ya no acepta donaciones.';

    // ---------- DTOs ----------

    /**
     * @description Datos públicos de una campaña vigente.
     */
    public class CampanaPublicaDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String nombre;
        @AuraEnabled public String descripcion;
        @AuraEnabled public String proposito;
        @AuraEnabled public String imagenUrl;
        @AuraEnabled public Decimal meta;
        @AuraEnabled public Decimal recaudado;
        @AuraEnabled public Decimal porcentaje;
        @AuraEnabled public Date fechaFin;
        @AuraEnabled public Boolean elegibleParaDonar;
        @AuraEnabled public String motivoCierre;
    }

    /**
     * @description Entrada del muro de reconocimiento: solo nombre público y monto (RF-C1 CA2).
     */
    public class DonanteReconocimientoDTO {
        @AuraEnabled public String nombrePublico;
        @AuraEnabled public Decimal monto;
    }

    /**
     * @description Datos que envía el formulario público.
     */
    public class SolicitudDonacionDTO {
        @AuraEnabled public Id campanaId { get; set; }
        @AuraEnabled public String modalidad { get; set; }
        @AuraEnabled public Decimal monto { get; set; }
        @AuraEnabled public String correo { get; set; }
        @AuraEnabled public String nombre { get; set; }
        @AuraEnabled public String nombrePublico { get; set; }
        @AuraEnabled public String rfc { get; set; }
    }

    private class StripeException extends Exception {}

    // ---------- Campañas (US-01) ----------

    /**
     * @description Campañas vigentes (activas y dentro de sus fechas), con su avance y si aceptan donaciones.
     * @return Lista de campañas públicas ordenadas por fecha fin.
     */
    @AuraEnabled(cacheable=true)
    public static List<CampanaPublicaDTO> obtenerCampanasActivas() {
        List<CampanaPublicaDTO> resultado = new List<CampanaPublicaDTO>();
        for (Campana__c c : [
            SELECT Id, Name, Descripcion__c, Proposito__c, Imagen_URL__c, Meta__c, Monto_Recaudado__c,
                   Fecha_Fin__c, Permitir_Sobrecupo__c
            FROM Campana__c
            WHERE Vigente__c = true
            WITH SYSTEM_MODE
            ORDER BY Fecha_Fin__c ASC, Name ASC
            LIMIT 200
        ]) {
            resultado.add(aDto(c));
        }
        return resultado;
    }

    private static CampanaPublicaDTO aDto(Campana__c c) {
        Decimal meta = c.Meta__c == null ? 0 : c.Meta__c;
        Decimal recaudado = c.Monto_Recaudado__c == null ? 0 : c.Monto_Recaudado__c;
        CampanaPublicaDTO dto = new CampanaPublicaDTO();
        dto.id = c.Id;
        dto.nombre = c.Name;
        dto.descripcion = c.Descripcion__c;
        dto.proposito = c.Proposito__c;
        dto.imagenUrl = c.Imagen_URL__c;
        dto.meta = meta;
        dto.recaudado = recaudado;
        dto.porcentaje = meta > 0 ? (recaudado * 100 / meta).setScale(1, System.RoundingMode.HALF_UP) : 0;
        dto.fechaFin = c.Fecha_Fin__c;
        dto.elegibleParaDonar = aceptaDonaciones(c);
        dto.motivoCierre = dto.elegibleParaDonar ? null : 'Meta alcanzada';
        return dto;
    }

    private static Boolean aceptaDonaciones(Campana__c c) {
        Decimal recaudado = c.Monto_Recaudado__c == null ? 0 : c.Monto_Recaudado__c;
        return c.Permitir_Sobrecupo__c == true || recaudado < c.Meta__c;
    }

    // ---------- Muro de reconocimiento (US-04) ----------

    /**
     * @description Donantes públicos de una campaña: donaciones Pagadas con crédito o con factura y visibles.
     *              Devuelve solo nombre público (o el nombre del donante si no hay) y monto.
     * @param campanaId Campaña a consultar.
     * @return Lista de entradas del muro, de la más reciente a la más antigua.
     */
    @AuraEnabled(cacheable=true)
    public static List<DonanteReconocimientoDTO> obtenerMuroDonantes(Id campanaId) {
        List<DonanteReconocimientoDTO> resultado = new List<DonanteReconocimientoDTO>();
        if (campanaId == null || campanaId.getSobjectType() != Campana__c.SObjectType) {
            return resultado;
        }
        for (Donacion__c d : [
            SELECT Nombre_Publico__c, Nombre_Donante__c, Monto__c
            FROM Donacion__c
            WHERE Campana__c = :campanaId
              AND Estado__c = 'Pagada'
              AND Modalidad__c IN ('Con crédito', 'Con factura')
              AND Visible_En_Reconocimiento__c = true
            WITH SYSTEM_MODE
            ORDER BY Fecha_Pago__c DESC NULLS LAST
            LIMIT :MAX_DONANTES_MURO
        ]) {
            DonanteReconocimientoDTO dto = new DonanteReconocimientoDTO();
            dto.nombrePublico = String.isNotBlank(d.Nombre_Publico__c) ? d.Nombre_Publico__c : d.Nombre_Donante__c;
            dto.monto = d.Monto__c;
            resultado.add(dto);
        }
        return resultado;
    }

    // ---------- Inicio de la donación (US-02, US-03, US-05, US-06) ----------

    /**
     * @description Valida la solicitud, crea la sesión de Stripe Checkout y registra la donación Pendiente.
     * @param solicitud Datos del formulario.
     * @return Únicamente la URL de Stripe Checkout.
     */
    @AuraEnabled
    public static String iniciarDonacion(SolicitudDonacionDTO solicitud) {
        Campana__c campana = validarSolicitud(solicitud);

        Stripe_Config__c config = Stripe_Config__c.getOrgDefaults();
        if (config == null || String.isBlank(config.Secret_Key__c)
            || String.isBlank(config.Success_URL__c) || String.isBlank(config.Cancel_URL__c)) {
            throw error('El pago en línea no está disponible en este momento.');
        }

        String referencia = UUID.randomUUID().toString();
        Map<String, Object> sesion;
        try {
            sesion = crearSesionStripe(config, campana, solicitud, referencia);
        } catch (Exception ex) {
            throw error(MSG_GENERICO);
        }

        Donacion__c donacion = new Donacion__c(
            Campana__c = campana.Id,
            Modalidad__c = solicitud.modalidad,
            Monto__c = solicitud.monto,
            Correo__c = solicitud.correo,
            Nombre_Donante__c = solicitud.nombre,
            Nombre_Publico__c = solicitud.nombrePublico,
            RFC__c = solicitud.rfc,
            Estado__c = 'Pendiente',
            Referencia_Publica__c = referencia,
            Stripe_Session_Id__c = String.valueOf(sesion.get('id'))
        );
        try {
            insert as system donacion;
        } catch (Exception ex) {
            throw error(MSG_GENERICO);
        }
        return String.valueOf(sesion.get('url'));
    }

    /**
     * @description Valida y normaliza la solicitud. Devuelve la campaña si acepta donaciones.
     */
    private static Campana__c validarSolicitud(SolicitudDonacionDTO s) {
        if (s == null || s.campanaId == null || s.campanaId.getSobjectType() != Campana__c.SObjectType) {
            throw error('Selecciona una campaña.');
        }
        List<Campana__c> campanas = [
            SELECT Id, Name, Meta__c, Monto_Recaudado__c, Permitir_Sobrecupo__c, Vigente__c
            FROM Campana__c WHERE Id = :s.campanaId WITH SYSTEM_MODE LIMIT 1
        ];
        if (campanas.isEmpty() || !campanas[0].Vigente__c || !aceptaDonaciones(campanas[0])) {
            throw error(MSG_CERRADA);
        }

        // Monto (US-02 AC3/AC5): mínimo $10.00, máximo 2 decimales, sin máximo propio
        if (s.monto == null || s.monto < MONTO_MINIMO) {
            throw error('El monto mínimo es $10.00 MXN.');
        }
        if (s.monto != s.monto.setScale(2, System.RoundingMode.DOWN)) {
            throw error('El monto puede tener como máximo dos decimales.');
        }

        // Correo (US-03 AC6): obligatorio en todas las modalidades
        s.correo = s.correo == null ? null : s.correo.trim();
        if (String.isBlank(s.correo) || s.correo.length() > 80 || !PATRON_CORREO.matcher(s.correo).matches()) {
            throw error('Escribe un correo electrónico válido.');
        }

        if (!MODALIDADES.contains(s.modalidad)) {
            throw error('Elige cómo quieres donar.');
        }
        s.nombre = limpiar(s.nombre);
        s.nombrePublico = limpiar(s.nombrePublico);
        s.rfc = limpiar(s.rfc);

        if (s.modalidad == 'Anónima') {
            // US-03: no se guarda ningún dato de identidad
            s.nombre = null;
            s.nombrePublico = null;
            s.rfc = null;
        } else {
            if (String.isBlank(s.nombre)) {
                throw error(s.modalidad == 'Con factura'
                    ? 'Escribe tu nombre o razón social.'
                    : 'Escribe tu nombre para aparecer en el muro.');
            }
            if (s.nombre.length() > 255 || (s.nombrePublico != null && s.nombrePublico.length() > 80)) {
                throw error('El nombre es demasiado largo.');
            }
            if (s.modalidad == 'Con crédito') {
                s.rfc = null;
            } else {
                s.rfc = RfcValidator.normalizar(s.rfc);
                if (!RfcValidator.esValido(s.rfc)) {
                    throw error('Escribe un RFC válido (12 o 13 caracteres, con una fecha que exista).');
                }
            }
        }
        return campanas[0];
    }

    private static String limpiar(String valor) {
        return String.isBlank(valor) ? null : valor.trim();
    }

    /**
     * @description Crea la sesión de Stripe Checkout. Solo envía la referencia opaca, nunca el Id.
     */
    private static Map<String, Object> crearSesionStripe(
        Stripe_Config__c config, Campana__c campana, SolicitudDonacionDTO s, String referencia
    ) {
        Long centavos = (s.monto * 100).setScale(0, System.RoundingMode.HALF_UP).longValue();
        Long expiraEn = System.now().getTime() / 1000 + EXPIRACION_SEGUNDOS;

        List<String> partes = new List<String>{
            par('mode', 'payment'),
            par('submit_type', 'donate'),
            // Sin payment_method_types: Stripe ya no lo acepta; los métodos (tarjeta)
            // se configuran en el Dashboard (Settings > Payment methods).
            par('locale', 'es'),
            par('client_reference_id', referencia),
            par('metadata[referencia]', referencia),
            par('customer_email', s.correo),
            par('line_items[0][quantity]', '1'),
            par('line_items[0][price_data][currency]', 'mxn'),
            par('line_items[0][price_data][unit_amount]', String.valueOf(centavos)),
            par('line_items[0][price_data][product_data][name]', 'Donación: ' + campana.Name),
            par('expires_at', String.valueOf(expiraEn)),
            par('success_url', config.Success_URL__c),
            par('cancel_url', config.Cancel_URL__c)
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(STRIPE_ENDPOINT);
        req.setMethod('POST');
        req.setTimeout(20000);
        req.setHeader('Authorization', 'Bearer ' + config.Secret_Key__c);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setHeader('Idempotency-Key', referencia);
        req.setBody(String.join(partes, '&'));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new StripeException('Stripe respondió HTTP ' + res.getStatusCode());
        }
        Map<String, Object> sesion = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        if (sesion.get('id') == null || sesion.get('url') == null) {
            throw new StripeException('Respuesta de Stripe incompleta');
        }
        return sesion;
    }

    private static String par(String clave, String valor) {
        return EncodingUtil.urlEncode(clave, 'UTF-8') + '=' + EncodingUtil.urlEncode(valor, 'UTF-8');
    }

    private static AuraHandledException error(String mensaje) {
        AuraHandledException ex = new AuraHandledException(mensaje);
        ex.setMessage(mensaje);
        return ex;
    }
}
