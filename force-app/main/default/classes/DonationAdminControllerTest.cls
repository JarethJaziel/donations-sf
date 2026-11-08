/**
 * @description Suite de pruebas unitarias para DonationAdminController (US-12).
 *              Verifica la obtención de resúmenes de confirmación, pagos manuales de Tesorería,
 *              bloqueos de doble confirmación y validación de estados y parámetros nulos.
 */
@IsTest
@SuppressWarnings('PMD')
private class DonationAdminControllerTest {

    @TestSetup
    static void setupTestData() {
        Campana__c campana = new Campana__c(
            Name = 'Campaña Mexico Dreamin Admin Test',
            Meta__c = 100000.00,
            Activa__c = true,
            Permitir_Sobrecupo__c = true,
            Fecha_Inicio__c = Date.today().addDays(-1),
            Fecha_Fin__c = Date.today().addDays(60),
            Proposito__c = 'Becas ficticias para estudiantes (dato de prueba).'
        );
        insert campana;

        List<Donacion__c> donaciones = new List<Donacion__c>();

        // 1. Donación pendiente en modalidad Con crédito
        donaciones.add(new Donacion__c(
            Campana__c = campana.Id,
            Monto__c = 2500.00,
            Modalidad__c = 'Con crédito',
            Nombre_Donante__c = 'Donante Admin Test',
            Correo__c = 'admin.donante@example.com',
            Estado__c = 'Pendiente'
        ));

        // 2. Donación pendiente en modalidad Con factura
        donaciones.add(new Donacion__c(
            Campana__c = campana.Id,
            Monto__c = 4500.00,
            Modalidad__c = 'Con factura',
            Nombre_Donante__c = 'Empresa Fiscal SA de CV',
            RFC__c = 'XAXX010101000',
            Correo__c = 'fiscal.admin@example.com',
            Estado__c = 'Pendiente'
        ));

        // 3. Donación expirada
        donaciones.add(new Donacion__c(
            Campana__c = campana.Id,
            Monto__c = 1000.00,
            Modalidad__c = 'Anónima',
            Correo__c = 'admin.expirada@example.com',
            Estado__c = 'Expirada'
        ));

        insert donaciones;
    }

    /**
     * @description Verifica la obtención de resumen DTO para una donación pendiente (US-12 AC1).
     */
    @isTest
    static void testObtenerResumenDonacionExitoso() {
        Donacion__c don = [
            SELECT Id, Name, Monto__c, Modalidad__c, Estado__c, Nombre_Donante__c
            FROM Donacion__c
            WHERE Modalidad__c = 'Con crédito'
            LIMIT 1
        ];

        Test.startTest();
        DonationAdminController.ResumenConfirmacionDTO dto = DonationAdminController.obtenerResumenDonacion(don.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'El DTO no debe ser nulo');
        System.assertEquals(don.Id, dto.id, 'El ID debe coincidir');
        System.assertEquals(don.Name, dto.folio, 'El folio debe coincidir');
        System.assertEquals('Campaña Mexico Dreamin Admin Test', dto.campanaNombre, 'El nombre de campaña debe coincidir');
        System.assertEquals(2500.00, dto.monto, 'El monto debe coincidir');
        System.assertEquals('Con crédito', dto.modalidad, 'La modalidad debe ser Con crédito');
        System.assertEquals('Pendiente', dto.estado, 'El estado debe ser Pendiente');
        System.assertEquals('Donante Admin Test', dto.nombreDonante, 'El nombre del donante debe coincidir');
        System.assertEquals(false, dto.solicitaFactura, 'No debe solicitar factura');

        // Prueba con donación que sí solicita factura
        Donacion__c donFactura = [
            SELECT Id FROM Donacion__c WHERE Modalidad__c = 'Con factura' LIMIT 1
        ];
        DonationAdminController.ResumenConfirmacionDTO dtoFactura = DonationAdminController.obtenerResumenDonacion(donFactura.Id);
        System.assertEquals(true, dtoFactura.solicitaFactura, 'Debe indicar que solicita factura');
    }

    /**
     * @description Verifica la confirmación manual exitosa de pago por Tesorería (US-12 AC2/AC3).
     */
    @isTest
    static void testConfirmarPagoManualExitoso() {
        DonationReceiptService.simulacionEnvio = 'exito';
        Donacion__c don = [
            SELECT Id, Estado__c, Tipo_Confirmacion__c, Comprobante_Enviado__c
            FROM Donacion__c
            WHERE Modalidad__c = 'Con crédito'
            LIMIT 1
        ];

        System.assertEquals('Pendiente', don.Estado__c, 'Estado inicial debe ser Pendiente');
        System.assertEquals(false, don.Comprobante_Enviado__c, 'Comprobante no enviado inicialmente');

        Test.startTest();
        DonationAdminController.ResultadoConfirmacionDTO resultado = DonationAdminController.confirmarPagoManual(don.Id);
        Test.stopTest();

        System.assertNotEquals(null, resultado, 'El resultado no debe ser nulo');
        System.assertEquals(true, resultado.exito, 'La operación debe ser exitosa');
        System.assertEquals('Pagada', resultado.nuevoEstado, 'El nuevo estado debe ser Pagada');
        System.assertEquals('Manual', resultado.tipoConfirmacion, 'El tipo de confirmación debe ser Manual');

        Donacion__c donConfirmada = [
            SELECT Id, Estado__c, Tipo_Confirmacion__c, Comprobante_Enviado__c
            FROM Donacion__c
            WHERE Id = :don.Id
        ];
        System.assertEquals('Pagada', donConfirmada.Estado__c, 'Debe persistirse en estado Pagada');
        System.assertEquals('Manual', donConfirmada.Tipo_Confirmacion__c, 'Tipo_Confirmacion__c debe ser Manual');
        System.assertEquals(true, donConfirmada.Comprobante_Enviado__c, 'Debe enviarse el comprobante automáticamente');
    }

    /**
     * @description Verifica el bloqueo estricto ante intentos de doble confirmación manual (US-12 AC4).
     */
    @isTest
    static void testBloqueoDobleConfirmacionManual() {
        Donacion__c don = [
            SELECT Id FROM Donacion__c WHERE Modalidad__c = 'Con crédito' LIMIT 1
        ];

        // Primera confirmación exitosa
        DonationAdminController.confirmarPagoManual(don.Id);

        Test.startTest();
        try {
            // Intento de segunda confirmación manual
            DonationAdminController.confirmarPagoManual(don.Id);
            System.assert(false, 'Se esperaba una AuraHandledException al reconfirmar una donación ya pagada');
        } catch (AuraHandledException ex) {
            System.assert(
                ex.getMessage().contains('ya fue confirmada como Pagada previamente') ||
                ex.getMessage().contains('Script-thrown exception'),
                'El mensaje de error debe alertar sobre doble confirmación: ' + ex.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description Verifica que no se puedan confirmar manualmente donaciones que no estén en estado Pendiente.
     */
    @isTest
    static void testBloqueoConfirmacionEstadoNoPendiente() {
        Donacion__c donExpirada = [
            SELECT Id FROM Donacion__c WHERE Estado__c = 'Expirada' LIMIT 1
        ];

        Test.startTest();
        try {
            DonationAdminController.confirmarPagoManual(donExpirada.Id);
            System.assert(false, 'Se esperaba una AuraHandledException al intentar confirmar una donación expirada');
        } catch (AuraHandledException ex) {
            System.assert(
                ex.getMessage().contains('Solo las donaciones en estado Pendiente pueden confirmarse') ||
                ex.getMessage().contains('Script-thrown exception'),
                'El mensaje de error debe indicar la restricción de estado: ' + ex.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description Valida el manejo de excepciones ante identificadores nulos o inexistentes.
     */
    @isTest
    static void testExcepcionesIdNuloONoEncontrado() {
        Test.startTest();

        // 1. obtenerResumenDonacion con null
        try {
            DonationAdminController.obtenerResumenDonacion(null);
            System.assert(false, 'Se esperaba AuraHandledException con ID nulo');
        } catch (AuraHandledException ex) {
            System.assert(
                ex.getMessage().contains('obligatorio') || ex.getMessage().contains('Script-thrown exception'),
                'Mensaje esperado para ID nulo: ' + ex.getMessage()
            );
        }

        // 2. confirmarPagoManual con null
        try {
            DonationAdminController.confirmarPagoManual(null);
            System.assert(false, 'Se esperaba AuraHandledException con ID nulo');
        } catch (AuraHandledException ex) {
            System.assert(
                ex.getMessage().contains('obligatorio') || ex.getMessage().contains('Script-thrown exception'),
                'Mensaje esperado para ID nulo: ' + ex.getMessage()
            );
        }

        // 3. ID ficticio que no existe en base de datos
        Campana__c c = [SELECT Id FROM Campana__c LIMIT 1];
        Donacion__c temp = new Donacion__c(
            Campana__c = c.Id,
            Monto__c = 100,
            Modalidad__c = 'Anónima',
            Correo__c = 'temp@example.com'
        );
        insert temp;
        Id idEliminado = temp.Id;
        delete temp;

        try {
            DonationAdminController.obtenerResumenDonacion(idEliminado);
            System.assert(false, 'Se esperaba AuraHandledException para ID inexistente');
        } catch (AuraHandledException ex) {
            System.assert(
                ex.getMessage().contains('No se encontró') || ex.getMessage().contains('Script-thrown exception'),
                'Mensaje esperado para ID no encontrado: ' + ex.getMessage()
            );
        }

        try {
            DonationAdminController.confirmarPagoManual(idEliminado);
            System.assert(false, 'Se esperaba AuraHandledException para ID inexistente');
        } catch (AuraHandledException ex) {
            System.assert(
                ex.getMessage().contains('No se encontró') || ex.getMessage().contains('Script-thrown exception'),
                'Mensaje esperado para ID no encontrado: ' + ex.getMessage()
            );
        }

        Test.stopTest();
    }
}
