/**
 * @description Pruebas de DonationPublicController (US-01 a US-06, US-15 AC5).
 *              Stripe se simula con HttpCalloutMock; los datos son ficticios (M1) y la llave es falsa (M3).
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class DonationPublicControllerTest {

    private static final String URL_CHECKOUT = 'https://checkout.stripe.com/c/pay/sesion_simulada';

    /**
     * @description Simula la API de Stripe y guarda la última solicitud para revisarla.
     */
    private class StripeMock implements HttpCalloutMock {
        Integer status;
        String body;
        HttpRequest ultima;
        StripeMock(Integer status, String body) {
            this.status = status;
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            ultima = req;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setBody(body);
            return res;
        }
    }

    private static StripeMock mockExitoso() {
        StripeMock mock = new StripeMock(200, JSON.serialize(new Map<String, Object>{
            'id' => 'sesion_simulada_001', 'url' => URL_CHECKOUT
        }));
        Test.setMock(HttpCalloutMock.class, mock);
        return mock;
    }

    @TestSetup
    static void setup() {
        Stripe_Config__c config = Stripe_Config__c.getOrgDefaults();
        config.Secret_Key__c = 'LLAVE_FALSA_SOLO_PARA_PRUEBAS';
        config.Success_URL__c = 'https://portal.example.com/agradecimiento';
        config.Cancel_URL__c = 'https://portal.example.com/pago-cancelado';
        upsert config;

        Campana__c vigente = DonacionTestFactory.campanaVigente('Campaña Vigente', 1000);
        vigente.Imagen_URL__c = 'https://portal.example.com/imagen.png';

        Campana__c llena = DonacionTestFactory.campanaVigente('Campaña Llena Sin Sobrecupo', 100);
        llena.Permitir_Sobrecupo__c = false;

        Campana__c futura = DonacionTestFactory.campanaVigente('Campaña Futura', 1000);
        futura.Fecha_Inicio__c = Date.today().addDays(5);
        futura.Fecha_Fin__c = Date.today().addDays(40);

        Campana__c inactiva = DonacionTestFactory.campanaVigente('Campaña Inactiva', 1000);
        inactiva.Activa__c = false;
        insert new List<Campana__c>{ vigente, llena, futura, inactiva };

        // Donaciones ya pagadas (se insertan como Pagada con comprobante enviado para no disparar correos)
        List<Donacion__c> pagadas = new List<Donacion__c>();
        Donacion__c credito = DonacionTestFactory.donacion(vigente.Id, 'Con crédito', 300, 'credito@example.com');
        credito.Nombre_Publico__c = 'Familia Ficticia';
        Donacion__c factura = DonacionTestFactory.donacion(vigente.Id, 'Con factura', 200, 'factura@example.com');
        Donacion__c anonima = DonacionTestFactory.donacion(vigente.Id, 'Anónima', 50, 'anonima@example.com');
        Donacion__c oculta = DonacionTestFactory.donacion(vigente.Id, 'Con crédito', 25, 'oculta@example.com');
        oculta.Nombre_Donante__c = 'Nombre Oculto Por Moderación';
        oculta.Visible_En_Reconocimiento__c = false;
        Donacion__c llenaPago = DonacionTestFactory.donacion(llena.Id, 'Anónima', 100, 'llena@example.com');
        for (Donacion__c d : new List<Donacion__c>{ credito, factura, anonima, oculta, llenaPago }) {
            d.Estado__c = 'Pagada';
            d.Tipo_Confirmacion__c = 'Manual';
            d.Comprobante_Enviado__c = true;
            pagadas.add(d);
        }
        Donacion__c pendiente = DonacionTestFactory.donacion(vigente.Id, 'Con crédito', 999, 'pendiente@example.com');
        pendiente.Nombre_Donante__c = 'Donante Pendiente';
        pagadas.add(pendiente);
        insert pagadas;
    }

    private static Campana__c campana(String nombre) {
        return [SELECT Id FROM Campana__c WHERE Name = :nombre LIMIT 1];
    }

    private static DonationPublicController.SolicitudDonacionDTO solicitud(String modalidad, Decimal monto) {
        DonationPublicController.SolicitudDonacionDTO s = new DonationPublicController.SolicitudDonacionDTO();
        s.campanaId = campana('Campaña Vigente').Id;
        s.modalidad = modalidad;
        s.monto = monto;
        s.correo = 'donante@example.com';
        if (modalidad != 'Anónima') {
            s.nombre = 'Donante Ficticio';
        }
        if (modalidad == 'Con factura') {
            s.rfc = 'EKU9003173C9';
        }
        return s;
    }

    private static String errorDe(DonationPublicController.SolicitudDonacionDTO s) {
        try {
            DonationPublicController.iniciarDonacion(s);
            return null;
        } catch (AuraHandledException ex) {
            return ex.getMessage();
        }
    }

    // ---------- Campañas (US-01) ----------

    @IsTest
    static void soloMuestraCampanasVigentes() {
        List<DonationPublicController.CampanaPublicaDTO> campanas = DonationPublicController.obtenerCampanasActivas();
        Set<String> nombres = new Set<String>();
        for (DonationPublicController.CampanaPublicaDTO c : campanas) {
            nombres.add(c.nombre);
        }
        System.assert(nombres.contains('Campaña Vigente'));
        System.assert(nombres.contains('Campaña Llena Sin Sobrecupo'));
        System.assertEquals(false, nombres.contains('Campaña Futura'), 'Una campaña futura no se muestra (US-01 AC6)');
        System.assertEquals(false, nombres.contains('Campaña Inactiva'), 'Una campaña inactiva no se muestra');
    }

    @IsTest
    static void calculaAvanceYElegibilidad() {
        for (DonationPublicController.CampanaPublicaDTO c : DonationPublicController.obtenerCampanasActivas()) {
            if (c.nombre == 'Campaña Vigente') {
                System.assertEquals(575, c.recaudado, 'Solo suman las donaciones Pagadas (US-01 AC2)');
                System.assertEquals(57.5, c.porcentaje);
                System.assertEquals(true, c.elegibleParaDonar);
                System.assertEquals('https://portal.example.com/imagen.png', c.imagenUrl);
                System.assertNotEquals(null, c.proposito);
            } else if (c.nombre == 'Campaña Llena Sin Sobrecupo') {
                System.assertEquals(false, c.elegibleParaDonar, 'Llena y sin sobrecupo no acepta donaciones (US-01 AC5)');
                System.assertEquals('Meta alcanzada', c.motivoCierre);
            }
        }
    }

    // ---------- Muro (US-04) ----------

    @IsTest
    static void muroSoloMuestraNombrePublicoYMonto() {
        List<DonationPublicController.DonanteReconocimientoDTO> muro =
            DonationPublicController.obtenerMuroDonantes(campana('Campaña Vigente').Id);
        System.assertEquals(2, muro.size(), 'Solo Pagadas, con crédito o factura y visibles');

        Set<String> nombres = new Set<String>();
        for (DonationPublicController.DonanteReconocimientoDTO d : muro) {
            nombres.add(d.nombrePublico);
        }
        System.assert(nombres.contains('Familia Ficticia'), 'Usa el nombre público cuando existe');
        System.assert(nombres.contains('Empresa Ficticia SA de CV'), 'Sin nombre público usa el nombre del donante');
        System.assertEquals(false, nombres.contains('Nombre Oculto Por Moderación'), 'Las entradas ocultas no aparecen (US-04 AC6)');
        System.assertEquals(false, nombres.contains('Donante Pendiente'), 'Las pendientes no aparecen');

        String json = JSON.serialize(muro);
        System.assertEquals(false, json.contains('@'), 'No debe exponer correos (M2)');
        System.assertEquals(false, json.contains('XAXX010101000'), 'No debe exponer RFC (M2)');
        System.assertEquals(false, json.containsIgnoreCase('fecha'), 'No debe exponer la fecha (RF-C1 CA2)');
    }

    @IsTest
    static void muroConIdInvalidoDevuelveVacio() {
        System.assertEquals(0, DonationPublicController.obtenerMuroDonantes(null).size());
        Donacion__c ajena = [SELECT Id FROM Donacion__c LIMIT 1];
        System.assertEquals(0, DonationPublicController.obtenerMuroDonantes(ajena.Id).size(),
            'El Id de una donación no sirve para consultar nada (US-15 AC5)');
    }

    // ---------- Inicio de la donación (US-02, US-03, US-05, US-06) ----------

    @IsTest
    static void donacionAnonimaCreaPendienteConReferenciaOpaca() {
        StripeMock mock = mockExitoso();
        DonationPublicController.SolicitudDonacionDTO s = solicitud('Anónima', 135.50);
        s.nombre = 'No debe guardarse';
        s.rfc = 'EKU9003173C9';

        Test.startTest();
        String url = DonationPublicController.iniciarDonacion(s);
        Test.stopTest();

        System.assertEquals(URL_CHECKOUT, url, 'Solo se devuelve la URL de Checkout');
        Donacion__c don = [
            SELECT Id, Estado__c, Monto__c, Nombre_Donante__c, RFC__c, Referencia_Publica__c, Stripe_Session_Id__c
            FROM Donacion__c WHERE Stripe_Session_Id__c = 'sesion_simulada_001'
        ];
        System.assertEquals('Pendiente', don.Estado__c, 'Se registra Pendiente antes de abrir la pasarela (US-06 AC1)');
        System.assertEquals(135.50, don.Monto__c);
        System.assertEquals(null, don.Nombre_Donante__c, 'Anónima no guarda nombre (US-03)');
        System.assertEquals(null, don.RFC__c, 'Anónima no guarda RFC (US-03)');

        String body = EncodingUtil.urlDecode(mock.ultima.getBody(), 'UTF-8');
        System.assertEquals('POST', mock.ultima.getMethod());
        System.assert(body.contains('client_reference_id=' + don.Referencia_Publica__c), 'Envía la referencia opaca');
        System.assertEquals(false, body.contains(String.valueOf(don.Id)), 'Nunca envía el Id del registro (US-06 AC5)');
        System.assertEquals(false, body.contains(String.valueOf(don.Id).left(15)), 'Ni el Id corto');
        System.assert(body.contains('unit_amount]=13550'), 'Monto en centavos (US-02 AC1)');
        System.assert(body.contains('currency]=mxn'));
        System.assert(body.contains('expires_at='), 'La sesión expira (US-06 AC4)');
        System.assert(body.contains('success_url=https://portal.example.com/agradecimiento'));
        System.assert(body.contains('cancel_url=https://portal.example.com/pago-cancelado'));
    }

    @IsTest
    static void donacionConFacturaNormalizaRfcYGuardaNombrePublico() {
        mockExitoso();
        DonationPublicController.SolicitudDonacionDTO s = solicitud('Con factura', 20000);
        s.rfc = '  eku9003173c9 ';
        s.nombrePublico = '  Empresa Patrocinadora  ';

        Test.startTest();
        DonationPublicController.iniciarDonacion(s);
        Test.stopTest();

        Donacion__c don = [
            SELECT RFC__c, Nombre_Publico__c, Solicita_Factura__c, Tipo_Persona__c
            FROM Donacion__c WHERE Stripe_Session_Id__c = 'sesion_simulada_001'
        ];
        System.assertEquals('EKU9003173C9', don.RFC__c);
        System.assertEquals('Empresa Patrocinadora', don.Nombre_Publico__c);
        System.assertEquals(true, don.Solicita_Factura__c);
        System.assertEquals('Moral', don.Tipo_Persona__c);
    }

    @IsTest
    static void donacionConCreditoDescartaRfc() {
        mockExitoso();
        DonationPublicController.SolicitudDonacionDTO s = solicitud('Con crédito', 50000);
        s.rfc = 'EKU9003173C9';
        Test.startTest();
        DonationPublicController.iniciarDonacion(s);
        Test.stopTest();
        Donacion__c don = [SELECT RFC__c, Monto__c FROM Donacion__c WHERE Stripe_Session_Id__c = 'sesion_simulada_001'];
        System.assertEquals(null, don.RFC__c);
        System.assertEquals(50000, don.Monto__c, 'Sin máximo propio (US-02 AC5)');
    }

    @IsTest
    static void rechazaMontosInvalidos() {
        mockExitoso();
        System.assert(errorDe(solicitud('Anónima', 9.99)).contains('$10.00'), 'Mínimo $10 (US-02 AC3)');
        System.assert(errorDe(solicitud('Anónima', null)).contains('$10.00'));
        System.assert(errorDe(solicitud('Anónima', 10.555)).contains('dos decimales'));
        System.assert(errorDe(solicitud('Anónima', 1000000.00)).contains('999,999.99'), 'Excede el límite técnico de 8 dígitos de Stripe');
        System.assertEquals(0, [SELECT COUNT() FROM Donacion__c WHERE Stripe_Session_Id__c = 'sesion_simulada_001'],
            'No se crea ningún registro (US-02 AC3)');
    }

    @IsTest
    static void rechazaDatosDelDonanteInvalidos() {
        mockExitoso();
        DonationPublicController.SolicitudDonacionDTO sinCorreo = solicitud('Anónima', 100);
        sinCorreo.correo = 'correo-invalido';
        System.assert(errorDe(sinCorreo).contains('correo'));

        DonationPublicController.SolicitudDonacionDTO sinModalidad = solicitud('Anónima', 100);
        sinModalidad.modalidad = 'Efectivo';
        System.assert(errorDe(sinModalidad).contains('Elige'));

        DonationPublicController.SolicitudDonacionDTO creditoSinNombre = solicitud('Con crédito', 100);
        creditoSinNombre.nombre = '   ';
        System.assert(errorDe(creditoSinNombre).contains('nombre'), 'Con crédito exige nombre (US-04 AC3)');

        DonationPublicController.SolicitudDonacionDTO facturaSinNombre = solicitud('Con factura', 100);
        facturaSinNombre.nombre = null;
        System.assert(errorDe(facturaSinNombre).contains('razón social'), 'Con factura exige nombre (US-05 AC1)');

        DonationPublicController.SolicitudDonacionDTO rfcFechaInexistente = solicitud('Con factura', 100);
        rfcFechaInexistente.rfc = 'GODE560230GR8';
        System.assert(errorDe(rfcFechaInexistente).contains('RFC'), 'RFC con 30 de febrero (US-05 AC5)');

        DonationPublicController.SolicitudDonacionDTO nombreLargo = solicitud('Con crédito', 100);
        nombreLargo.nombrePublico = 'x'.repeat(81);
        System.assert(errorDe(nombreLargo).contains('largo'));
    }

    @IsTest
    static void rechazaCampanasQueNoAceptanDonaciones() {
        mockExitoso();
        System.assert(errorDe(null).contains('campaña'));

        DonationPublicController.SolicitudDonacionDTO llena = solicitud('Anónima', 100);
        llena.campanaId = campana('Campaña Llena Sin Sobrecupo').Id;
        System.assert(errorDe(llena).contains('ya no acepta'), 'Llena y sin sobrecupo (US-01 AC5)');

        DonationPublicController.SolicitudDonacionDTO futura = solicitud('Anónima', 100);
        futura.campanaId = campana('Campaña Futura').Id;
        System.assert(errorDe(futura).contains('ya no acepta'), 'Campaña que no ha iniciado');

        DonationPublicController.SolicitudDonacionDTO idAjeno = solicitud('Anónima', 100);
        idAjeno.campanaId = [SELECT Id FROM Donacion__c LIMIT 1].Id;
        System.assert(errorDe(idAjeno).contains('campaña'), 'El Id de una donación no se acepta (US-15 AC5)');
    }

    @IsTest
    static void errorDeStripeNoCreaRegistro() {
        Test.setMock(HttpCalloutMock.class, new StripeMock(400, '{"error":{"message":"simulado"}}'));
        Integer antes = [SELECT COUNT() FROM Donacion__c];
        Test.startTest();
        String error = errorDe(solicitud('Anónima', 100));
        Test.stopTest();
        System.assert(error.contains('No pudimos iniciar'), error);
        System.assertEquals(antes, [SELECT COUNT() FROM Donacion__c], 'Si Stripe falla no se inserta nada');
    }

    @IsTest
    static void respuestaIncompletaDeStripeNoCreaRegistro() {
        Test.setMock(HttpCalloutMock.class, new StripeMock(200, '{"id":"sesion_sin_url"}'));
        Integer antes = [SELECT COUNT() FROM Donacion__c];
        Test.startTest();
        System.assert(errorDe(solicitud('Anónima', 100)).contains('No pudimos iniciar'));
        Test.stopTest();
        System.assertEquals(antes, [SELECT COUNT() FROM Donacion__c]);
    }

    @IsTest
    static void sinConfiguracionDeStripeNoPermitePagar() {
        delete [SELECT Id FROM Stripe_Config__c];
        mockExitoso();
        Test.startTest();
        System.assert(errorDe(solicitud('Anónima', 100)).contains('no está disponible'));
        Test.stopTest();
    }

    @IsTest
    static void errorAlInsertarDevuelveMensajeGenerico() {
        // Una sesión con el mismo Id que una donación existente provoca un error de duplicado al insertar
        Donacion__c existente = [SELECT Id FROM Donacion__c WHERE Estado__c = 'Pendiente' LIMIT 1];
        existente.Stripe_Session_Id__c = 'sesion_simulada_001';
        update existente;
        mockExitoso();
        Test.startTest();
        System.assert(errorDe(solicitud('Anónima', 100)).contains('No pudimos iniciar'));
        Test.stopTest();
    }
}
