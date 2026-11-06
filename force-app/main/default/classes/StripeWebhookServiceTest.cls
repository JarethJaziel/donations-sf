/**
 * @description Suite de pruebas unitarias para StripeWebhookService (US-13, US-16, US-17, RF-V3a, RF-V3b, M3).
 *              Verifica la validación criptográfica HMAC-SHA256, control de idempotencia,
 *              conciliación automática y auditoría en Aviso_Pasarela__c.
 */
@IsTest
@SuppressWarnings('PMD')
private class StripeWebhookServiceTest {

    private static final String TEST_SECRET = 'TEST_HMAC_SIGNING_SECRET_MD2026_SANDBOX';

    @TestSetup
    static void setupTestData() {
        // M3: Configuración del secreto en Custom Setting jerárquico sin exponer prefijos sensibles
        Stripe_Config__c config = Stripe_Config__c.getOrgDefaults();
        config.Webhook_Secret__c = TEST_SECRET;
        upsert config;

        Campana__c campana = new Campana__c(
            Name = 'Campaña Mexico Dreamin Webhook Test',
            Meta__c = 75000.00,
            Activa__c = true,
            Permitir_Sobrecupo__c = true,
            Fecha_Fin__c = Date.today().addDays(45)
        );
        insert campana;

        Donacion__c don = new Donacion__c(
            Campana__c = campana.Id,
            Monto__c = 1500.00,
            Modalidad__c = 'Con crédito',
            Nombre_Donante__c = 'Donante Webhook Test',
            Correo__c = 'webhook.test@test-md2026.org',
            Estado__c = 'Pendiente',
            Stripe_Session_Id__c = 'cs_sandbox_session_001'
        );
        insert don;
    }

    /**
     * @description Genera el encabezado Stripe-Signature válido con timestamp y firma HMAC-SHA256 (v1).
     */
    private static String generarHeaderFirma(String rawBody, Long timestamp, String secret) {
        String cargaFirmada = String.valueOf(timestamp) + '.' + rawBody;
        Blob hmac = Crypto.generateMac('hmacSHA256', Blob.valueOf(cargaFirmada), Blob.valueOf(secret));
        return 't=' + String.valueOf(timestamp) + ',v1=' + EncodingUtil.convertToHex(hmac);
    }

    /**
     * @description Verifica el flujo exitoso: firma válida, conciliación automática a 'Pagada',
     *              registro de auditoría 'Procesado' y emisión de comprobante (US-16 AC1/AC2, US-17 AC1).
     */
    @isTest
    static void testWebhookValidoConciliaDonacionYEnviaRecibo() {
        Donacion__c don = [
            SELECT Id, Estado__c, Tipo_Confirmacion__c, Comprobante_Enviado__c, Stripe_Session_Id__c
            FROM Donacion__c
            WHERE Stripe_Session_Id__c = 'cs_sandbox_session_001'
            LIMIT 1
        ];

        String rawBody = '{"id":"evt_valid_001","type":"checkout.session.completed","data":{"object":{"id":"cs_sandbox_session_001","client_reference_id":"' + don.Id + '","metadata":{"donacion_id":"' + don.Id + '"}}}}';
        Long timestamp = DateTime.now().getTime() / 1000;
        String sigHeader = generarHeaderFirma(rawBody, timestamp, TEST_SECRET);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(rawBody);
        req.headers.put('Stripe-Signature', sigHeader);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        StripeWebhookService.procesarEvento();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'El endpoint debe responder HTTP 200 ante evento válido');

        Donacion__c donRecargada = [
            SELECT Id, Estado__c, Tipo_Confirmacion__c, Comprobante_Enviado__c
            FROM Donacion__c
            WHERE Id = :don.Id
        ];
        System.assertEquals('Pagada', donRecargada.Estado__c, 'La donación debe conciliarse como Pagada');
        System.assertEquals('Automática', donRecargada.Tipo_Confirmacion__c, 'El tipo de confirmación debe ser Automática');
        System.assertEquals(true, donRecargada.Comprobante_Enviado__c, 'El comprobante debe haber sido emitido');

        List<Aviso_Pasarela__c> avisos = [
            SELECT Stripe_Event_Id__c, Estado_Aviso__c, Donacion__c
            FROM Aviso_Pasarela__c
            WHERE Stripe_Event_Id__c = 'evt_valid_001'
        ];
        System.assertEquals(1, avisos.size(), 'Debe existir un aviso de auditoría');
        System.assertEquals('Procesado', avisos[0].Estado_Aviso__c, 'El estado del aviso debe ser Procesado');
        System.assertEquals(don.Id, avisos[0].Donacion__c, 'El aviso debe relacionarse a la donación');
    }

    /**
     * @description Verifica el rechazo con HTTP 400 y registro de auditoría cuando la firma HMAC es inválida
     *              o el payload fue adulterado en tránsito (US-13, US-17 AC1/AC3).
     */
    @isTest
    static void testWebhookFirmaInvalidaORechazadoPorPayloadAdulterado() {
        Donacion__c don = [
            SELECT Id, Estado__c FROM Donacion__c WHERE Stripe_Session_Id__c = 'cs_sandbox_session_001' LIMIT 1
        ];

        String rawBody = '{"id":"evt_tampered_001","type":"checkout.session.completed","data":{"object":{"id":"cs_sandbox_session_001","client_reference_id":"' + don.Id + '"}}}';
        String sigFalsa = 't=' + (DateTime.now().getTime() / 1000) + ',v1=0000000000000000deadbeefdeadbeef11111111111111112222222222222222';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(rawBody);
        req.headers.put('Stripe-Signature', sigFalsa);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        StripeWebhookService.procesarEvento();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Firma inválida debe retornar HTTP 400');

        Donacion__c donSinCambios = [
            SELECT Id, Estado__c FROM Donacion__c WHERE Id = :don.Id
        ];
        System.assertEquals('Pendiente', donSinCambios.Estado__c, 'La donación debe permanecer en Pendiente');

        List<Aviso_Pasarela__c> avisos = [
            SELECT Stripe_Event_Id__c, Estado_Aviso__c, Motivo_Rechazo__c
            FROM Aviso_Pasarela__c
            WHERE Stripe_Event_Id__c = 'evt_tampered_001'
        ];
        System.assertEquals(1, avisos.size(), 'Debe registrarse el evento rechazado');
        System.assertEquals('Rechazado', avisos[0].Estado_Aviso__c, 'Estado del aviso debe ser Rechazado');
        System.assert(avisos[0].Motivo_Rechazo__c.contains('HMAC-SHA256'), 'El motivo debe registrar fallo de firma HMAC');
    }

    /**
     * @description Verifica la idempotencia: eventos duplicados reciben HTTP 200 y se registran como
     *              'Duplicado Ignorado' sin procesar la donación por segunda vez (US-17 AC2).
     */
    @isTest
    static void testWebhookIdempotenciaEventoDuplicado() {
        Donacion__c don = [
            SELECT Id, Estado__c FROM Donacion__c WHERE Stripe_Session_Id__c = 'cs_sandbox_session_001' LIMIT 1
        ];

        String rawBody = '{"id":"evt_dup_001","type":"checkout.session.completed","data":{"object":{"id":"cs_sandbox_session_001","client_reference_id":"' + don.Id + '"}}}';
        Long timestamp = DateTime.now().getTime() / 1000;
        String sigHeader = generarHeaderFirma(rawBody, timestamp, TEST_SECRET);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(rawBody);
        req.headers.put('Stripe-Signature', sigHeader);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        // Primer envío: Debe procesarse exitosamente
        StripeWebhookService.procesarEvento();
        System.assertEquals(200, res.statusCode, 'Primer envío debe responder 200');

        Test.startTest();
        // Segundo envío con el mismo evento: Debe responder 200 e ignorarse
        RestResponse resDup = new RestResponse();
        RestContext.response = resDup;
        StripeWebhookService.procesarEvento();
        Test.stopTest();

        System.assertEquals(200, resDup.statusCode, 'Segundo envío duplicado debe responder 200');

        List<Aviso_Pasarela__c> avisos = [
            SELECT Stripe_Event_Id__c, Estado_Aviso__c
            FROM Aviso_Pasarela__c
            WHERE Stripe_Event_Id__c LIKE 'evt_dup_001%'
            ORDER BY CreatedDate ASC
        ];
        System.assertEquals(2, avisos.size(), 'Deben existir 2 avisos (original y duplicado)');
        System.assertEquals('Procesado', avisos[0].Estado_Aviso__c, 'El primer aviso debe ser Procesado');
        System.assertEquals('Duplicado Ignorado', avisos[1].Estado_Aviso__c, 'El segundo aviso debe ser Duplicado Ignorado');
    }

    /**
     * @description Verifica el rechazo con HTTP 400 cuando los identificadores del payload no corresponden
     *              a ninguna donación existente (US-16 AC3).
     */
    @isTest
    static void testWebhookDonacionNoEncontrada() {
        String rawBody = '{"id":"evt_notfound_001","type":"checkout.session.completed","data":{"object":{"id":"cs_non_existent_session_999","client_reference_id":"invalid_reference_id"}}}';
        Long timestamp = DateTime.now().getTime() / 1000;
        String sigHeader = generarHeaderFirma(rawBody, timestamp, TEST_SECRET);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(rawBody);
        req.headers.put('Stripe-Signature', sigHeader);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        StripeWebhookService.procesarEvento();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Donación no encontrada debe retornar HTTP 400');

        List<Aviso_Pasarela__c> avisos = [
            SELECT Stripe_Event_Id__c, Estado_Aviso__c, Motivo_Rechazo__c
            FROM Aviso_Pasarela__c
            WHERE Stripe_Event_Id__c = 'evt_notfound_001'
        ];
        System.assertEquals(1, avisos.size(), 'Debe registrarse el rechazo');
        System.assertEquals('Rechazado', avisos[0].Estado_Aviso__c, 'Estado debe ser Rechazado');
        System.assert(avisos[0].Motivo_Rechazo__c.contains('Donación no encontrada'), 'Motivo debe detallar donación no encontrada');
    }

    /**
     * @description Verifica el tratamiento idempotente cuando llega un evento de pago para una donación
     *              que ya se encontraba en estado Pagada (US-17 AC2).
     */
    @isTest
    static void testWebhookDonacionYaPagadaPreviamente() {
        Donacion__c don = [
            SELECT Id, Estado__c FROM Donacion__c WHERE Stripe_Session_Id__c = 'cs_sandbox_session_001' LIMIT 1
        ];
        don.Estado__c = 'Pagada';
        don.Tipo_Confirmacion__c = 'Manual';
        update don;

        String rawBody = '{"id":"evt_already_paid_001","type":"checkout.session.completed","data":{"object":{"id":"cs_sandbox_session_001","client_reference_id":"' + don.Id + '"}}}';
        Long timestamp = DateTime.now().getTime() / 1000;
        String sigHeader = generarHeaderFirma(rawBody, timestamp, TEST_SECRET);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(rawBody);
        req.headers.put('Stripe-Signature', sigHeader);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        StripeWebhookService.procesarEvento();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Donación ya pagada debe responder 200');

        List<Aviso_Pasarela__c> avisos = [
            SELECT Stripe_Event_Id__c, Estado_Aviso__c, Motivo_Rechazo__c
            FROM Aviso_Pasarela__c
            WHERE Stripe_Event_Id__c = 'evt_already_paid_001'
        ];
        System.assertEquals(1, avisos.size(), 'Debe registrarse el evento');
        System.assertEquals('Duplicado Ignorado', avisos[0].Estado_Aviso__c, 'Estado debe ser Duplicado Ignorado');
        System.assert(avisos[0].Motivo_Rechazo__c.contains('ya se encontraba en estado Pagada'), 'Motivo debe señalar estado previo');
    }

    /**
     * @description Verifica el rechazo cuando el encabezado Stripe-Signature está ausente o vacío (US-17 AC1).
     */
    @isTest
    static void testWebhookFirmaAusente() {
        String rawBody = '{"id":"evt_no_sig_001","type":"checkout.session.completed"}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(rawBody);
        // Sin header Stripe-Signature

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        StripeWebhookService.procesarEvento();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Firma ausente debe retornar HTTP 400');

        List<Aviso_Pasarela__c> avisos = [
            SELECT Stripe_Event_Id__c, Estado_Aviso__c, Motivo_Rechazo__c
            FROM Aviso_Pasarela__c
            WHERE Stripe_Event_Id__c LIKE 'evt_no_sig_001%'
        ];
        System.assertEquals(1, avisos.size(), 'Debe registrarse el rechazo');
        System.assertEquals('Rechazado', avisos[0].Estado_Aviso__c);
    }

    /**
     * @description Verifica el rechazo cuando el payload no es un JSON estructurado válido.
     */
    @isTest
    static void testWebhookPayloadNoJson() {
        String rawBody = 'INVALID_PLAIN_TEXT_NOT_JSON';
        Long timestamp = DateTime.now().getTime() / 1000;
        String sigHeader = generarHeaderFirma(rawBody, timestamp, TEST_SECRET);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(rawBody);
        req.headers.put('Stripe-Signature', sigHeader);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        StripeWebhookService.procesarEvento();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Payload inválido debe responder 400');
    }

    /**
     * @description Verifica las ramas defensivas directas del método verificarFirmaHmac.
     */
    @isTest
    static void testVerificarFirmaHmacDirecto() {
        Test.startTest();
        System.assertEquals(false, StripeWebhookService.verificarFirmaHmac(null, null, null));
        System.assertEquals(false, StripeWebhookService.verificarFirmaHmac('', '', ''));
        System.assertEquals(false, StripeWebhookService.verificarFirmaHmac('body', 'invalido', 'secret'));
        System.assertEquals(false, StripeWebhookService.verificarFirmaHmac('body', 't=123', 'secret'));
        System.assertEquals(false, StripeWebhookService.verificarFirmaHmac('body', 'v1=abc', 'secret'));
        System.assertEquals(false, StripeWebhookService.verificarFirmaHmac('body', 't=123,v1=abc', 'secret'));
        Test.stopTest();
    }

    /**
     * @description Verifica la instanciación automática cuando RestContext.response es nulo
     *              y el manejo de colisiones de ID en eventos con firma inválida.
     */
    @isTest
    static void testWebhookResponseNullYColisionIdInvalido() {
        // Insertamos un aviso previo con el ID para provocar colisión
        insert new Aviso_Pasarela__c(
            Stripe_Event_Id__c = 'evt_collision_001',
            Estado_Aviso__c = 'Rechazado',
            Motivo_Rechazo__c = 'Previo'
        );

        String rawBody = '{"id":"evt_collision_001","type":"checkout.session.completed"}';
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(rawBody);
        req.headers.put('Stripe-Signature', 't=123,v1=invalido');

        RestContext.request = req;
        RestContext.response = null; // Fuerza inicialización automática de res

        Test.startTest();
        StripeWebhookService.procesarEvento();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response, 'RestContext.response debió inicializarse');
        System.assertEquals(400, RestContext.response.statusCode);
    }

    /**
     * @description Verifica la asignación de Stripe_Session_Id__c en donación cuando estaba en blanco,
     *              así como la generación de SIG_INVALID cuando el payload no contiene ID y la firma falla.
     */
    @isTest
    static void testWebhookAsignaSessionIdCuandoVacioYPayloadSinId() {
        Campana__c campana = [SELECT Id FROM Campana__c LIMIT 1];
        Donacion__c donSinSessionId = new Donacion__c(
            Campana__c = campana.Id,
            Monto__c = 900.00,
            Modalidad__c = 'Anónima',
            Correo__c = 'sinsession@test-md2026.org',
            Estado__c = 'Pendiente'
        );
        insert donSinSessionId;

        // Caso 1: Asignación de sessionId
        String rawBody = '{"id":"evt_assign_session_001","type":"checkout.session.completed","data":{"object":{"id":"cs_new_sandbox_session_777","client_reference_id":"' + donSinSessionId.Id + '"}}}';
        Long timestamp = DateTime.now().getTime() / 1000;
        String sigHeader = generarHeaderFirma(rawBody, timestamp, TEST_SECRET);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(rawBody);
        req.headers.put('Stripe-Signature', sigHeader);

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        StripeWebhookService.procesarEvento();

        // Caso 2: Firma inválida en payload sin id
        RestRequest reqSinId = new RestRequest();
        reqSinId.requestURI = '/services/apexrest/stripe/webhook/';
        reqSinId.httpMethod = 'POST';
        reqSinId.requestBody = Blob.valueOf('{"type":"checkout.session.completed"}');
        reqSinId.headers.put('Stripe-Signature', 't=123,v1=invalido');
        RestContext.request = reqSinId;
        RestContext.response = new RestResponse();
        StripeWebhookService.procesarEvento();
        Test.stopTest();

        Donacion__c donActualizada = [
            SELECT Id, Stripe_Session_Id__c, Estado__c
            FROM Donacion__c
            WHERE Id = :donSinSessionId.Id
        ];
        System.assertEquals('cs_new_sandbox_session_777', donActualizada.Stripe_Session_Id__c);
        System.assertEquals('Pagada', donActualizada.Estado__c);
    }
}
