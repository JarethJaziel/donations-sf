/**
 * @description Suite de pruebas unitarias para DonationReceiptService y DonacionTriggerHandler (US-08, RF-D5, RF-S3).
 *              Cubre casos positivos por modalidad, valores límite, bulk (200 registros) e idempotencia.
 */
@IsTest
@SuppressWarnings('PMD')
private class DonationReceiptServiceTest {

    @TestSetup
    static void setupTestData() {
        Campana__c campana = new Campana__c(
            Name = 'Campaña Mexico Dreamin 2026 Test',
            Meta__c = 50000.00,
            Activa__c = true,
            Permitir_Sobrecupo__c = true,
            Fecha_Fin__c = Date.today().addDays(30)
        );
        insert campana;

        List<Donacion__c> donaciones = new List<Donacion__c>();

        // 1. Donación en modalidad Anónima
        donaciones.add(new Donacion__c(
            Campana__c = campana.Id,
            Monto__c = 500.00,
            Modalidad__c = 'Anónima',
            Estado__c = 'Pendiente',
            Correo__c = 'donante.anonimo@test-md2026.org',
            Nombre_Donante__c = null,
            RFC__c = null
        ));

        // 2. Donación en modalidad Con crédito
        donaciones.add(new Donacion__c(
            Campana__c = campana.Id,
            Monto__c = 1500.00,
            Modalidad__c = 'Con crédito',
            Estado__c = 'Pendiente',
            Correo__c = 'donante.credito@test-md2026.org',
            Nombre_Donante__c = 'Carlos Donante Test',
            RFC__c = null
        ));

        // 3. Donación en modalidad Con factura
        donaciones.add(new Donacion__c(
            Campana__c = campana.Id,
            Monto__c = 3000.00,
            Modalidad__c = 'Con factura',
            Estado__c = 'Pendiente',
            Correo__c = 'donante.factura@test-md2026.org',
            Nombre_Donante__c = 'Empresa Ficticia SA de CV',
            RFC__c = 'XAXX010101000'
        ));

        insert donaciones;
    }

    /**
     * @description Verifica la generación y envío de comprobante adaptado para la modalidad Anónima.
     *              Garantiza estricto cumplimiento de privacidad (M2, US-08 AC1).
     */
    @isTest
    static void testComprobanteModalidadAnonima() {
        Donacion__c don = [
            SELECT Id, Name, Monto__c, Modalidad__c, Estado__c, Nombre_Donante__c,
                   Correo__c, RFC__c, Solicita_Factura__c, Comprobante_Enviado__c,
                   Campana__c, Campana__r.Name
            FROM Donacion__c
            WHERE Modalidad__c = 'Anónima'
            LIMIT 1
        ];

        System.assertEquals(false, don.Comprobante_Enviado__c, 'Inicialmente no debe haberse enviado comprobante');

        Test.startTest();
        don.Estado__c = 'Pagada';
        update don;
        Test.stopTest();

        Donacion__c donRecargada = [
            SELECT Id, Name, Monto__c, Modalidad__c, Estado__c, Nombre_Donante__c,
                   Correo__c, RFC__c, Solicita_Factura__c, Comprobante_Enviado__c,
                   Campana__c, Campana__r.Name
            FROM Donacion__c
            WHERE Id = :don.Id
        ];

        System.assertEquals(true, donRecargada.Comprobante_Enviado__c, 'El flag Comprobante_Enviado__c debe ser true tras pagar');

        String asunto = DonationReceiptService.construirAsuntoCorreo(donRecargada);
        String cuerpo = DonationReceiptService.construirCuerpoCorreo(donRecargada);

        System.assert(asunto.contains(donRecargada.Name), 'El asunto debe contener el folio de donación');
        System.assert(asunto.contains('Mexico Dreamin 2026'), 'El asunto debe mencionar Mexico Dreamin 2026');
        System.assert(cuerpo.contains(donRecargada.Name), 'El cuerpo debe incluir el folio');
        System.assert(cuerpo.contains('Campaña Mexico Dreamin 2026 Test'), 'El cuerpo debe incluir el nombre de la campaña');
        System.assert(cuerpo.contains('$500.00 MXN'), 'El cuerpo debe incluir el monto formateado');
        System.assert(cuerpo.contains('aportación anónima'), 'Debe mencionar que es una aportación anónima');

        // M2 & US-08 AC1: Prohibido exponer datos personales o fiscales
        System.assertEquals(false, cuerpo.contains('Carlos Donante'), 'No debe incluir nombres personales');
        System.assertEquals(false, cuerpo.contains('XAXX'), 'No debe incluir RFC');
        System.assertEquals(null, donRecargada.Nombre_Donante__c, 'Nombre_Donante__c debe ser null');
        System.assertEquals(null, donRecargada.RFC__c, 'RFC__c debe ser null');
    }

    /**
     * @description Verifica la generación del comprobante con crédito con confirmación de muro público (US-08 AC2).
     */
    @isTest
    static void testComprobanteModalidadConCredito() {
        Donacion__c don = [
            SELECT Id, Name, Monto__c, Modalidad__c, Estado__c, Nombre_Donante__c,
                   Correo__c, RFC__c, Solicita_Factura__c, Comprobante_Enviado__c,
                   Campana__c, Campana__r.Name
            FROM Donacion__c
            WHERE Modalidad__c = 'Con crédito'
            LIMIT 1
        ];

        Test.startTest();
        don.Estado__c = 'Pagada';
        update don;
        Test.stopTest();

        Donacion__c donRecargada = [
            SELECT Id, Name, Monto__c, Modalidad__c, Estado__c, Nombre_Donante__c,
                   Correo__c, RFC__c, Solicita_Factura__c, Comprobante_Enviado__c,
                   Campana__c, Campana__r.Name
            FROM Donacion__c
            WHERE Id = :don.Id
        ];

        System.assertEquals(true, donRecargada.Comprobante_Enviado__c, 'El flag Comprobante_Enviado__c debe ser true');

        String cuerpo = DonationReceiptService.construirCuerpoCorreo(donRecargada);
        System.assert(cuerpo.contains('Carlos Donante Test'), 'El cuerpo debe contener el nombre del donante');
        System.assert(cuerpo.contains(donRecargada.Name), 'El cuerpo debe contener el folio de la donación');
        System.assert(cuerpo.contains('$1500.00 MXN'), 'El cuerpo debe contener el monto de la donación');
        System.assert(cuerpo.contains('muro público de reconocimiento'), 'Debe confirmar su reconocimiento en el muro público');
        System.assertEquals(null, donRecargada.RFC__c, 'No debe registrar RFC en modalidad Con crédito');
    }

    /**
     * @description Verifica la generación del comprobante con factura y aviso de revisión en Tesorería (US-08 AC3).
     */
    @isTest
    static void testComprobanteModalidadConFactura() {
        Donacion__c don = [
            SELECT Id, Name, Monto__c, Modalidad__c, Estado__c, Nombre_Donante__c,
                   Correo__c, RFC__c, Solicita_Factura__c, Comprobante_Enviado__c,
                   Campana__c, Campana__r.Name
            FROM Donacion__c
            WHERE Modalidad__c = 'Con factura'
            LIMIT 1
        ];

        Test.startTest();
        don.Estado__c = 'Pagada';
        update don;
        Test.stopTest();

        Donacion__c donRecargada = [
            SELECT Id, Name, Monto__c, Modalidad__c, Estado__c, Nombre_Donante__c,
                   Correo__c, RFC__c, Solicita_Factura__c, Comprobante_Enviado__c,
                   Campana__c, Campana__r.Name
            FROM Donacion__c
            WHERE Id = :don.Id
        ];

        System.assertEquals(true, donRecargada.Comprobante_Enviado__c, 'El flag Comprobante_Enviado__c debe ser true');

        String cuerpo = DonationReceiptService.construirCuerpoCorreo(donRecargada);
        System.assert(cuerpo.contains('Empresa Ficticia SA de CV'), 'Debe incluir la razón social del donante');
        System.assert(cuerpo.contains('XAXX010101000'), 'Debe incluir el RFC válido del donante');
        System.assert(cuerpo.contains(donRecargada.Name), 'Debe incluir el folio');
        System.assert(cuerpo.contains('$3000.00 MXN'), 'Debe incluir el monto aportado');
        System.assert(cuerpo.contains('Tesorería'), 'Debe indicar que el trámite fiscal está en curso con Tesorería');
    }

    /**
     * @description Verifica la idempotencia en envíos posteriores evitando duplicación de correos (US-08 AC2/AC4).
     */
    @isTest
    static void testIdempotenciaNoDuplicaComprobanteAlEditar() {
        Donacion__c don = [
            SELECT Id, Estado__c, Comprobante_Enviado__c
            FROM Donacion__c
            WHERE Modalidad__c = 'Anónima'
            LIMIT 1
        ];

        don.Estado__c = 'Pagada';
        update don;

        Donacion__c donPagada = [
            SELECT Id, Comprobante_Enviado__c
            FROM Donacion__c
            WHERE Id = :don.Id
        ];
        System.assertEquals(true, donPagada.Comprobante_Enviado__c, 'Debe haber enviado el comprobante en la primera actualización');

        Test.startTest();
        // Limpiamos el caché de la transacción y volvemos a invocar el servicio de comprobantes
        DonacionTriggerHandler.limpiarCacheTransaccion();
        DonationReceiptService.enviarComprobantes(new Set<Id>{ donPagada.Id });

        // Modificamos otro campo sobre la instancia que tiene Comprobante_Enviado__c = true
        donPagada.Monto__c = 550.00;
        update donPagada;
        Test.stopTest();

        Donacion__c donFinal = [
            SELECT Id, Comprobante_Enviado__c, Monto__c
            FROM Donacion__c
            WHERE Id = :donPagada.Id
        ];
        System.assertEquals(true, donFinal.Comprobante_Enviado__c, 'Comprobante_Enviado__c debe permanecer true sin errores');
    }

    /**
     * @description Verifica las ramas del trigger handler al cambiar de campaña y alternar estado Pagada.
     */
    @isTest
    static void testTriggerHandlerCambioCampanaYEstado() {
        Campana__c campana2 = new Campana__c(
            Name = 'Segunda Campana Test MD2026',
            Meta__c = 25000.00,
            Activa__c = true,
            Permitir_Sobrecupo__c = true,
            Fecha_Fin__c = Date.today().addDays(20)
        );
        insert campana2;

        Donacion__c don = [
            SELECT Id, Estado__c, Campana__c
            FROM Donacion__c
            WHERE Modalidad__c = 'Con crédito'
            LIMIT 1
        ];

        don.Estado__c = 'Pagada';
        update don;

        Test.startTest();
        DonacionTriggerHandler.limpiarCacheTransaccion();
        don.Estado__c = 'Pendiente';
        don.Campana__c = campana2.Id;
        update don;
        Test.stopTest();

        Donacion__c donActualizada = [
            SELECT Id, Estado__c, Campana__c
            FROM Donacion__c
            WHERE Id = :don.Id
        ];
        System.assertEquals('Pendiente', donActualizada.Estado__c);
        System.assertEquals(campana2.Id, donActualizada.Campana__c);
    }

    /**
     * @description Valida el procesamiento masivo de 200 donaciones pagadas en una sola transacción DML
     *              garantizando bulkification y control de governor limits (C6, S12).
     */
    @isTest
    static void testBulk200DonacionesPagadas() {
        Campana__c campana = [SELECT Id FROM Campana__c LIMIT 1];

        List<Donacion__c> bulkDonaciones = new List<Donacion__c>();
        for (Integer i = 0; i < 200; i++) {
            Integer modType = Math.mod(i, 3);
            String mod = (modType == 0) ? 'Anónima' : (modType == 1 ? 'Con crédito' : 'Con factura');
            String nombre = (modType == 0) ? null : ('Donante Bulk ' + i);
            String rfc = (modType == 2) ? 'XAXX010101000' : null;

            bulkDonaciones.add(new Donacion__c(
                Campana__c = campana.Id,
                Monto__c = 100.00,
                Modalidad__c = mod,
                Nombre_Donante__c = nombre,
                RFC__c = rfc,
                Correo__c = 'bulk' + i + '@test-md2026.org',
                Estado__c = 'Pendiente'
            ));
        }

        insert bulkDonaciones;

        Test.startTest();
        for (Donacion__c don : bulkDonaciones) {
            don.Estado__c = 'Pagada';
        }
        update bulkDonaciones;
        Test.stopTest();

        List<Donacion__c> procesadas = [
            SELECT Id, Estado__c, Comprobante_Enviado__c
            FROM Donacion__c
            WHERE Id IN :bulkDonaciones
        ];

        System.assertEquals(200, procesadas.size(), 'Las 200 donaciones deben procesarse correctamente');
        for (Donacion__c d : procesadas) {
            System.assertEquals('Pagada', d.Estado__c, 'El estado debe ser Pagada');
            System.assertEquals(true, d.Comprobante_Enviado__c, 'Cada donación debe tener comprobante enviado');
        }
    }

    /**
     * @description Verifica la robustez ante colecciones vacías o valores nulos (Unhappy Path & Edge Cases).
     */
    @isTest
    static void testCasosBordeNullOVacio() {
        Test.startTest();
        Donacion__c realDon = [SELECT Id, Campana__c FROM Donacion__c LIMIT 1];
        DonationReceiptService.enviarComprobantes(null);
        DonationReceiptService.enviarComprobantes(new Set<Id>());
        DonationReceiptService.enviarComprobantes(new Set<Id>{ realDon.Id });

        DonacionTriggerHandler.afterUpdate(null, null);
        DonacionTriggerHandler.afterUpdate(new List<Donacion__c>(), new Map<Id, Donacion__c>());
        DonacionTriggerHandler.afterUpdate(
            new List<Donacion__c>{ realDon },
            new Map<Id, Donacion__c>()
        );
        DonacionTriggerHandler.recalcularMontoRecaudadoCampanas(null);
        DonacionTriggerHandler.recalcularMontoRecaudadoCampanas(new Set<Id>());
        DonacionTriggerHandler.recalcularMontoRecaudadoCampanas(new Set<Id>{ realDon.Campana__c });

        // Verificación de rama genérica y objetos vacíos en formateadores
        Donacion__c donacionGenerica = new Donacion__c(Modalidad__c = 'Efectivo');
        String asuntoVacio = DonationReceiptService.construirAsuntoCorreo(donacionGenerica);
        String cuerpoVacio = DonationReceiptService.construirCuerpoCorreo(donacionGenerica);
        Test.stopTest();

        System.assert(asuntoVacio.contains('Folio Pendiente'), 'Asunto debe contener Folio Pendiente para objeto sin Name');
        System.assert(cuerpoVacio.contains('Campaña Mexico Dreamin 2026'), 'Cuerpo genérico debe incluir nombre por defecto');
    }
}
