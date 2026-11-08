/**
 * @description Pruebas del modelo de datos: reglas de validación de Campaña y Donación y lógica
 *              before del trigger (referencia pública, RFC y fecha de pago).
 *              Cubre US-01 AC6, US-02 AC3, US-03, US-05 AC5/AC6, US-06 AC5, US-09 AC3/AC4, US-12 AC5 y US-13 AC4.
 */
@IsTest
private class ModeloDonacionesTest {

    @TestSetup
    static void setup() {
        insert DonacionTestFactory.campanaVigente('Campaña Modelo Test', 50000);
    }

    private static Campana__c campana() {
        return [SELECT Id, Meta__c, Fecha_Inicio__c FROM Campana__c LIMIT 1];
    }

    private static String errorAlInsertar(SObject registro) {
        try {
            insert registro;
            return null;
        } catch (DmlException ex) {
            return ex.getMessage();
        }
    }

    private static String errorAlActualizar(SObject registro) {
        try {
            update registro;
            return null;
        } catch (DmlException ex) {
            return ex.getMessage();
        }
    }

    // ---------- Campaña ----------

    @IsTest
    static void campanaExigeFechasYProposito() {
        Campana__c sinDatos = new Campana__c(Name = 'Sin datos', Meta__c = 1000);
        String error = errorAlInsertar(sinDatos);
        System.assertNotEquals(null, error, 'Debe exigir fechas y propósito');
        System.assert(error.contains('Fecha Inicio, Fecha Fin y Propósito'), error);
    }

    @IsTest
    static void campanaRechazaFechaFinAnteriorAInicio() {
        Campana__c c = DonacionTestFactory.campanaVigente('Fechas invertidas', 1000);
        c.Fecha_Inicio__c = Date.today().addDays(10);
        c.Fecha_Fin__c = Date.today().addDays(5);
        String error = errorAlInsertar(c);
        System.assertNotEquals(null, error);
        System.assert(error.contains('no puede ser anterior'), error);
    }

    @IsTest
    static void metaBloqueadaCuandoLaCampanaYaInicio() {
        Campana__c c = campana();
        c.Meta__c = 99999;
        String error = errorAlActualizar(c);
        System.assertNotEquals(null, error, 'No debe permitir cambiar la meta de una campaña iniciada');
        System.assert(error.contains('ya inició'), error);
    }

    @IsTest
    static void metaEditableAntesDeIniciar() {
        Campana__c futura = DonacionTestFactory.campanaVigente('Campaña futura', 1000);
        futura.Fecha_Inicio__c = Date.today().addDays(5);
        futura.Fecha_Fin__c = Date.today().addDays(40);
        insert futura;
        futura.Meta__c = 2000;
        System.assertEquals(null, errorAlActualizar(futura), 'Antes de iniciar la meta sí se puede cambiar');
    }

    @IsTest
    static void vigenteDependeDeLasFechas() {
        Campana__c futura = DonacionTestFactory.campanaVigente('No vigente aún', 1000);
        futura.Fecha_Inicio__c = Date.today().addDays(3);
        futura.Fecha_Fin__c = Date.today().addDays(20);
        insert futura;
        Map<Id, Campana__c> campanas = new Map<Id, Campana__c>([SELECT Id, Vigente__c FROM Campana__c]);
        System.assertEquals(true, campanas.get(campana().Id).Vigente__c, 'La campaña iniciada debe estar vigente');
        System.assertEquals(false, campanas.get(futura.Id).Vigente__c, 'La campaña futura no debe estar vigente');
    }

    // ---------- Donación ----------

    @IsTest
    static void donacionRechazaMontoMenorADiez() {
        Donacion__c don = DonacionTestFactory.donacion(campana().Id, 'Anónima', 9.99, 'minimo@example.com');
        String error = errorAlInsertar(don);
        System.assertNotEquals(null, error);
        System.assert(error.contains('$10.00'), error);
        Donacion__c valida = DonacionTestFactory.donacion(campana().Id, 'Anónima', 10, 'minimo@example.com');
        System.assertEquals(null, errorAlInsertar(valida), '$10.00 sí es válido');
    }

    @IsTest
    static void anonimaNoPermiteNombrePublico() {
        Donacion__c don = DonacionTestFactory.donacion(campana().Id, 'Anónima', 100, 'anonima@example.com');
        don.Nombre_Publico__c = 'Alguien';
        System.assertNotEquals(null, errorAlInsertar(don), 'Una donación anónima no puede tener nombre público');
    }

    @IsTest
    static void triggerGeneraReferenciaPublicaInmutable() {
        Donacion__c don = DonacionTestFactory.donacion(campana().Id, 'Anónima', 100, 'ref@example.com');
        insert don;
        don = [SELECT Id, Referencia_Publica__c FROM Donacion__c WHERE Id = :don.Id];
        System.assertEquals(36, don.Referencia_Publica__c.length(), 'Debe asignarse un UUID');

        don.Referencia_Publica__c = 'otra-referencia';
        String error = errorAlActualizar(don);
        System.assertNotEquals(null, error, 'La referencia no debe poder cambiarse');
        System.assert(error.contains('no se puede modificar'), error);
    }

    @IsTest
    static void triggerConservaReferenciaRecibida() {
        Donacion__c don = DonacionTestFactory.donacion(campana().Id, 'Anónima', 100, 'ref2@example.com');
        don.Referencia_Publica__c = '11111111-2222-3333-4444-555555555555';
        insert don;
        System.assertEquals('11111111-2222-3333-4444-555555555555',
            [SELECT Referencia_Publica__c FROM Donacion__c WHERE Id = :don.Id].Referencia_Publica__c);
    }

    @IsTest
    static void triggerNormalizaRfcYCalculaTipoPersona() {
        Donacion__c don = DonacionTestFactory.donacion(campana().Id, 'Con factura', 500, 'rfc@example.com');
        don.RFC__c = ' eku9003173c9';
        insert don;
        Donacion__c guardada = [SELECT RFC__c, Tipo_Persona__c FROM Donacion__c WHERE Id = :don.Id];
        System.assertEquals('EKU9003173C9', guardada.RFC__c, 'El RFC se guarda sin espacios y en mayúsculas');
        System.assertEquals('Moral', guardada.Tipo_Persona__c, 'RFC de 12 caracteres es persona moral');
    }

    @IsTest
    static void triggerRechazaRfcConFechaInexistente() {
        Donacion__c don = DonacionTestFactory.donacion(campana().Id, 'Con factura', 500, 'rfc@example.com');
        don.RFC__c = 'GODE560230GR8';
        String error = errorAlInsertar(don);
        System.assertNotEquals(null, error, 'Debe rechazar el 30 de febrero');
        System.assert(error.contains('no existe'), error);
    }

    @IsTest
    static void pagadaRequiereTipoDeConfirmacion() {
        Donacion__c don = DonacionTestFactory.donacion(campana().Id, 'Anónima', 100, 'bypass@example.com');
        insert don;
        don.Estado__c = 'Pagada';
        String error = errorAlActualizar(don);
        System.assertNotEquals(null, error, 'No debe poder marcarse Pagada sin tipo de confirmación');
        System.assert(error.contains('Confirmar Pago Manual'), error);
    }

    @IsTest
    static void tipoDeConfirmacionEsInmutableYRegistraFechaDePago() {
        Donacion__c don = DonacionTestFactory.donacion(campana().Id, 'Anónima', 100, 'tipo@example.com');
        insert don;
        don.Estado__c = 'Pagada';
        don.Tipo_Confirmacion__c = 'Manual';
        update don;
        Donacion__c pagada = [SELECT Id, Fecha_Pago__c, Tipo_Confirmacion__c FROM Donacion__c WHERE Id = :don.Id];
        System.assertNotEquals(null, pagada.Fecha_Pago__c, 'Debe registrarse la fecha de pago');

        pagada.Tipo_Confirmacion__c = 'Automática';
        String error = errorAlActualizar(pagada);
        System.assertNotEquals(null, error, 'El tipo de confirmación no debe cambiar');
        System.assert(error.contains('no se puede cambiar'), error);
    }

    @IsTest
    static void insertarComoPagadaRegistraFechaDePago() {
        Donacion__c don = DonacionTestFactory.donacion(campana().Id, 'Anónima', 100, 'semilla@example.com');
        don.Estado__c = 'Pagada';
        don.Tipo_Confirmacion__c = 'Manual';
        don.Comprobante_Enviado__c = true;
        insert don;
        System.assertNotEquals(null, [SELECT Fecha_Pago__c FROM Donacion__c WHERE Id = :don.Id].Fecha_Pago__c);
    }

    @IsTest
    static void handlerToleraColeccionesNulas() {
        DonacionTriggerHandler.beforeInsert(null);
        DonacionTriggerHandler.beforeUpdate(null, null);
        Donacion__c sinAnterior = new Donacion__c(Id = null);
        DonacionTriggerHandler.beforeUpdate(new List<Donacion__c>{ sinAnterior }, new Map<Id, Donacion__c>());
        System.assert(true, 'No debe lanzar excepciones');
    }
}
