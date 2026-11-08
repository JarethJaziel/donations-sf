/**
 * @description Pruebas de StripeWebhookService (US-13, US-16, US-17, M3).
 *              Firma HMAC y tolerancia de tiempo, tipos de evento, monto, idempotencia,
 *              reintentos tras fallo, errores inesperados y auditoría en Aviso_Pasarela__c.
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class StripeWebhookServiceTest {

    // Secreto ficticio solo para pruebas (M3: no es una llave real ni tiene prefijo de Stripe)
    private static final String TEST_SECRET = 'TEST_HMAC_SIGNING_SECRET_MD2026_SANDBOX';
    private static final String REFERENCIA = 'aaaaaaaa-bbbb-cccc-dddd-000000000001';
    private static final String SESION = 'cs_sandbox_session_001';

    @TestSetup
    static void setupTestData() {
        Stripe_Config__c config = Stripe_Config__c.getOrgDefaults();
        config.Webhook_Secret__c = TEST_SECRET;
        upsert config;

        Campana__c campana = DonacionTestFactory.campanaVigente('Campaña Webhook Test', 75000);
        insert campana;

        Donacion__c don = DonacionTestFactory.donacion(campana.Id, 'Con crédito', 1500, 'webhook.test@example.com');
        don.Referencia_Publica__c = REFERENCIA;
        don.Stripe_Session_Id__c = SESION;
        insert don;
    }

    // ---------- Utilidades ----------

    private static String evento(String eventId, String tipo, String paymentStatus, Long amountTotal, String moneda, String referencia) {
        Map<String, Object> sesion = new Map<String, Object>{ 'id' => SESION };
        if (referencia != null) {
            sesion.put('client_reference_id', referencia);
        }
        if (paymentStatus != null) {
            sesion.put('payment_status', paymentStatus);
        }
        if (amountTotal != null) {
            sesion.put('amount_total', amountTotal);
        }
        if (moneda != null) {
            sesion.put('currency', moneda);
        }
        return JSON.serialize(new Map<String, Object>{
            'id' => eventId,
            'type' => tipo,
            'data' => new Map<String, Object>{ 'object' => sesion }
        });
    }

    private static String eventoPagado(String eventId) {
        return evento(eventId, 'checkout.session.completed', 'paid', 150000, 'mxn', REFERENCIA);
    }

    private static String firma(String rawBody, Long timestamp, String secret) {
        Blob hmac = Crypto.generateMac('hmacSHA256', Blob.valueOf(timestamp + '.' + rawBody), Blob.valueOf(secret));
        return 't=' + timestamp + ',v1=' + EncodingUtil.convertToHex(hmac);
    }

    private static Long ahora() {
        return System.now().getTime() / 1000;
    }

    private static RestResponse enviar(String rawBody, String sigHeader) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(rawBody);
        if (sigHeader != null) {
            req.headers.put('Stripe-Signature', sigHeader);
        }
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        StripeWebhookService.procesarEvento();
        return res;
    }

    private static RestResponse enviarFirmado(String rawBody) {
        return enviar(rawBody, firma(rawBody, ahora(), TEST_SECRET));
    }

    private static Donacion__c donacion() {
        return [
            SELECT Id, Estado__c, Tipo_Confirmacion__c, Comprobante_Enviado__c, Fecha_Pago__c, Stripe_Session_Id__c
            FROM Donacion__c WHERE Referencia_Publica__c = :REFERENCIA
        ];
    }

    private static List<Aviso_Pasarela__c> avisos(String eventId) {
        return [
            SELECT Estado_Aviso__c, Motivo_Rechazo__c, Tipo_Evento__c, Donacion__c
            FROM Aviso_Pasarela__c WHERE Stripe_Event_Id__c = :eventId ORDER BY CreatedDate, Id
        ];
    }

    // ---------- Pago confirmado ----------

    @IsTest
    static void pagoCompletadoMarcaPagadaYEnviaComprobante() {
        DonationReceiptService.simulacionEnvio = 'exito';
        Test.startTest();
        RestResponse res = enviarFirmado(eventoPagado('evt_paid_001'));
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Donacion__c don = donacion();
        System.assertEquals('Pagada', don.Estado__c);
        System.assertEquals('Automática', don.Tipo_Confirmacion__c);
        System.assertEquals(true, don.Comprobante_Enviado__c, 'Debe enviarse el comprobante');
        System.assertNotEquals(null, don.Fecha_Pago__c, 'Debe registrarse la fecha de pago');

        List<Aviso_Pasarela__c> registro = avisos('evt_paid_001');
        System.assertEquals(1, registro.size());
        System.assertEquals('Procesado', registro[0].Estado_Aviso__c);
        System.assertEquals('checkout.session.completed', registro[0].Tipo_Evento__c);
        System.assertEquals(don.Id, registro[0].Donacion__c);
    }

    @IsTest
    static void pagoAsincronoExitosoMarcaPagada() {
        Test.startTest();
        enviarFirmado(evento('evt_async_001', 'checkout.session.async_payment_succeeded', 'paid', 150000, 'mxn', REFERENCIA));
        Test.stopTest();
        System.assertEquals('Pagada', donacion().Estado__c);
    }

    @IsTest
    static void buscaPorSesionSiNoHayReferencia() {
        Test.startTest();
        RestResponse res = enviarFirmado(evento('evt_session_001', 'checkout.session.completed', 'paid', 150000, 'mxn', null));
        Test.stopTest();
        System.assertEquals(200, res.statusCode);
        System.assertEquals('Pagada', donacion().Estado__c);
    }

    @IsTest
    static void completadoSinPagoSeIgnora() {
        Test.startTest();
        RestResponse res = enviarFirmado(evento('evt_unpaid_001', 'checkout.session.completed', 'unpaid', 150000, 'mxn', REFERENCIA));
        Test.stopTest();
        System.assertEquals(200, res.statusCode);
        System.assertEquals('Pendiente', donacion().Estado__c, 'Sin payment_status = paid no se marca Pagada');
        System.assertEquals('Ignorado', avisos('evt_unpaid_001')[0].Estado_Aviso__c);
    }

    // ---------- Expiración y otros eventos (US-16 AC3) ----------

    @IsTest
    static void sesionExpiradaMarcaExpirada() {
        Test.startTest();
        RestResponse res = enviarFirmado(evento('evt_expired_001', 'checkout.session.expired', 'unpaid', null, null, REFERENCIA));
        Test.stopTest();
        System.assertEquals(200, res.statusCode);
        System.assertEquals('Expirada', donacion().Estado__c);
        System.assertEquals('Procesado', avisos('evt_expired_001')[0].Estado_Aviso__c);
    }

    @IsTest
    static void expiracionDeDonacionPagadaSeIgnora() {
        enviarFirmado(eventoPagado('evt_paid_002'));
        Test.startTest();
        enviarFirmado(evento('evt_expired_002', 'checkout.session.expired', 'unpaid', null, null, REFERENCIA));
        Test.stopTest();
        System.assertEquals('Pagada', donacion().Estado__c, 'Una donación pagada no debe expirar');
        System.assertEquals('Ignorado', avisos('evt_expired_002')[0].Estado_Aviso__c);
    }

    @IsTest
    static void eventoNoUtilizadoSeIgnora() {
        Test.startTest();
        RestResponse res = enviarFirmado(evento('evt_other_001', 'payment_intent.created', null, null, null, REFERENCIA));
        Test.stopTest();
        System.assertEquals(200, res.statusCode);
        System.assertEquals('Pendiente', donacion().Estado__c);
        List<Aviso_Pasarela__c> registro = avisos('evt_other_001');
        System.assertEquals('Ignorado', registro[0].Estado_Aviso__c);
        System.assertEquals('payment_intent.created', registro[0].Tipo_Evento__c);
    }

    // ---------- Monto (US-16 AC4) ----------

    @IsTest
    static void montoDistintoSeRechazaSinPagar() {
        Test.startTest();
        RestResponse res = enviarFirmado(evento('evt_amount_001', 'checkout.session.completed', 'paid', 100, 'mxn', REFERENCIA));
        Test.stopTest();
        System.assertEquals(200, res.statusCode, 'Evento auténtico: no tiene caso que Stripe lo reintente');
        System.assertEquals('Pendiente', donacion().Estado__c);
        Aviso_Pasarela__c aviso = avisos('evt_amount_001')[0];
        System.assertEquals('Rechazado', aviso.Estado_Aviso__c);
        System.assert(aviso.Motivo_Rechazo__c.contains('monto'), aviso.Motivo_Rechazo__c);
    }

    @IsTest
    static void monedaDistintaSeRechaza() {
        Test.startTest();
        enviarFirmado(evento('evt_currency_001', 'checkout.session.completed', 'paid', 150000, 'usd', REFERENCIA));
        Test.stopTest();
        System.assertEquals('Pendiente', donacion().Estado__c);
        System.assertEquals('Rechazado', avisos('evt_currency_001')[0].Estado_Aviso__c);
    }

    // ---------- Firma (US-17 AC1, AC3, AC4) ----------

    @IsTest
    static void firmaInvalidaSeRechaza() {
        Test.startTest();
        RestResponse res = enviar(eventoPagado('evt_badsig_001'), 't=' + ahora() + ',v1=deadbeef');
        Test.stopTest();
        System.assertEquals(400, res.statusCode);
        System.assertEquals('Pendiente', donacion().Estado__c);
        Aviso_Pasarela__c aviso = avisos('evt_badsig_001')[0];
        System.assertEquals('Rechazado', aviso.Estado_Aviso__c);
        System.assert(aviso.Motivo_Rechazo__c.contains('HMAC-SHA256'));
    }

    @IsTest
    static void payloadAlteradoSeRechaza() {
        String original = eventoPagado('evt_tamper_001');
        String header = firma(original, ahora(), TEST_SECRET);
        String alterado = original.replace('150000', '1');
        Test.startTest();
        RestResponse res = enviar(alterado, header);
        Test.stopTest();
        System.assertEquals(400, res.statusCode);
        System.assertEquals('Pendiente', donacion().Estado__c);
    }

    @IsTest
    static void firmaAusenteSeRechaza() {
        Test.startTest();
        RestResponse res = enviar(eventoPagado('evt_nosig_001'), null);
        Test.stopTest();
        System.assertEquals(400, res.statusCode);
        System.assertEquals('Rechazado', avisos('evt_nosig_001')[0].Estado_Aviso__c);
    }

    @IsTest
    static void firmaAntiguaSeRechazaComoReenvio() {
        String body = eventoPagado('evt_replay_001');
        Test.startTest();
        RestResponse res = enviar(body, firma(body, ahora() - 301, TEST_SECRET));
        Test.stopTest();
        System.assertEquals(400, res.statusCode);
        System.assertEquals('Pendiente', donacion().Estado__c);
        System.assert(avisos('evt_replay_001')[0].Motivo_Rechazo__c.contains('5 minutos'));
    }

    @IsTest
    static void validarFirmaCubreRamasDefensivas() {
        System.assertNotEquals(null, StripeWebhookService.validarFirma(null, null, null, ahora()));
        System.assertNotEquals(null, StripeWebhookService.validarFirma('body', 't=123', 'secret', ahora()));
        String firmaTextoNoNumerico = firma('body', 0, 'secret').replace('t=0', 't=abc');
        System.assertNotEquals(null, StripeWebhookService.validarFirma('body', firmaTextoNoNumerico, 'secret', ahora()));
        System.assertEquals(false, StripeWebhookService.verificarFirmaHmac('body', 'v1=abc', 'secret'));
        System.assertEquals(false, StripeWebhookService.verificarFirmaHmac('body', 't=123,v1=abc', 'secret'));
        System.assertEquals(null, StripeWebhookService.validarFirma('body', firma('body', ahora(), 'secret'), 'secret', ahora()));
    }

    // ---------- Idempotencia (US-17 AC2, AC5) ----------

    @IsTest
    static void eventoDuplicadoSoloSeProcesaUnaVez() {
        String body = eventoPagado('evt_dup_001');
        enviarFirmado(body);
        Test.startTest();
        RestResponse res = enviarFirmado(body);
        Test.stopTest();
        System.assertEquals(200, res.statusCode);
        List<Aviso_Pasarela__c> registro = avisos('evt_dup_001');
        System.assertEquals(2, registro.size());
        System.assertEquals('Procesado', registro[0].Estado_Aviso__c);
        System.assertEquals('Duplicado Ignorado', registro[1].Estado_Aviso__c);
    }

    @IsTest
    static void reintentoTrasRechazoSeProcesa() {
        String body = eventoPagado('evt_retry_001');
        enviar(body, 't=' + ahora() + ',v1=deadbeef');
        System.assertEquals('Pendiente', donacion().Estado__c);
        Test.startTest();
        RestResponse res = enviarFirmado(body);
        Test.stopTest();
        System.assertEquals(200, res.statusCode);
        System.assertEquals('Pagada', donacion().Estado__c, 'Un evento antes rechazado no cuenta como duplicado');
    }

    @IsTest
    static void pagoDeDonacionYaPagadaSeMarcaDuplicado() {
        Donacion__c don = donacion();
        don.Estado__c = 'Pagada';
        don.Tipo_Confirmacion__c = 'Manual';
        update don;
        Test.startTest();
        RestResponse res = enviarFirmado(eventoPagado('evt_already_001'));
        Test.stopTest();
        System.assertEquals(200, res.statusCode);
        System.assertEquals('Manual', donacion().Tipo_Confirmacion__c, 'No debe cambiar el tipo de confirmación');
        System.assertEquals('Duplicado Ignorado', avisos('evt_already_001')[0].Estado_Aviso__c);
    }

    // ---------- Errores (US-16 AC2, AC5) ----------

    @IsTest
    static void donacionNoEncontradaSeRechaza() {
        Test.startTest();
        String body = evento('evt_notfound_001', 'checkout.session.completed', 'paid', 150000, 'mxn', 'referencia-inexistente')
            .replace(SESION, 'cs_sesion_inexistente');
        RestResponse res = enviarFirmado(body);
        Test.stopTest();
        System.assertEquals(400, res.statusCode);
        Aviso_Pasarela__c aviso = avisos('evt_notfound_001')[0];
        System.assertEquals('Rechazado', aviso.Estado_Aviso__c);
        System.assert(aviso.Motivo_Rechazo__c.contains('Donación no encontrada'));
    }

    @IsTest
    static void errorInesperadoHaceRollbackYPermiteReintento() {
        StripeWebhookService.forzarErrorInesperado = true;
        Test.startTest();
        RestResponse res = enviarFirmado(eventoPagado('evt_error_001'));
        Test.stopTest();
        System.assertEquals(500, res.statusCode, 'Debe responder 500 para que Stripe reintente');
        System.assertEquals('Pendiente', donacion().Estado__c, 'No debe quedar a medias');
        System.assertEquals('Error', avisos('evt_error_001')[0].Estado_Aviso__c);

        StripeWebhookService.forzarErrorInesperado = false;
        enviarFirmado(eventoPagado('evt_error_001'));
        System.assertEquals('Pagada', donacion().Estado__c, 'El reintento después de un Error se procesa');
    }

    @IsTest
    static void payloadNoJsonSeRechaza() {
        Test.startTest();
        RestResponse res = enviarFirmado('INVALID_PLAIN_TEXT_NOT_JSON');
        Test.stopTest();
        System.assertEquals(400, res.statusCode);
    }

    @IsTest
    static void creaRespuestaSiRestContextNoLaTiene() {
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf('{"id":"evt_null_res_001"}');
        RestContext.request = req;
        RestContext.response = null;
        Test.startTest();
        StripeWebhookService.procesarEvento();
        Test.stopTest();
        System.assertNotEquals(null, RestContext.response);
        System.assertEquals(400, RestContext.response.statusCode);
    }
}
