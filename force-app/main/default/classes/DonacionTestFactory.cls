/**
 * @description Fábrica de datos de prueba (M1: datos ficticios; correos en el dominio reservado example.com).
 *              Crea campañas con todos los campos obligatorios para que las pruebas no dependan de datos de la org.
 */
@IsTest
public class DonacionTestFactory {

    /**
     * @description Campaña vigente (inició ayer y termina en 30 días), sin insertar.
     * @param nombre Nombre de la campaña.
     * @param meta Meta financiera.
     * @return Campaña lista para insertar.
     */
    public static Campana__c campanaVigente(String nombre, Decimal meta) {
        return new Campana__c(
            Name = nombre,
            Meta__c = meta,
            Activa__c = true,
            Permitir_Sobrecupo__c = true,
            Fecha_Inicio__c = Date.today().addDays(-1),
            Fecha_Fin__c = Date.today().addDays(30),
            Descripcion__c = 'Campaña ficticia para pruebas unitarias.',
            Proposito__c = 'Becas ficticias para estudiantes (dato de prueba).'
        );
    }

    /**
     * @description Donación pendiente, sin insertar.
     * @param campanaId Campaña a la que pertenece.
     * @param modalidad Anónima, Con crédito o Con factura.
     * @param monto Monto en MXN.
     * @param correo Correo del donante (usar example.com).
     * @return Donación lista para insertar.
     */
    public static Donacion__c donacion(Id campanaId, String modalidad, Decimal monto, String correo) {
        Donacion__c don = new Donacion__c(
            Campana__c = campanaId,
            Modalidad__c = modalidad,
            Monto__c = monto,
            Correo__c = correo,
            Estado__c = 'Pendiente'
        );
        if (modalidad == 'Con crédito') {
            don.Nombre_Donante__c = 'Donante Ficticio Crédito';
        } else if (modalidad == 'Con factura') {
            don.Nombre_Donante__c = 'Empresa Ficticia SA de CV';
            don.RFC__c = 'XAXX010101000';
        }
        return don;
    }
}
