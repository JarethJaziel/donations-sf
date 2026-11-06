/**
 * @description Controlador para componentes administrativos de Donación en Lightning Experience (US-12).
 *              Permite a los usuarios internos de Tesorería consultar y confirmar pagos manuales.
 */
public with sharing class DonationAdminController {

    public class ResumenConfirmacionDTO {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String folio { get; set; }
        @AuraEnabled public String campanaNombre { get; set; }
        @AuraEnabled public Decimal monto { get; set; }
        @AuraEnabled public String modalidad { get; set; }
        @AuraEnabled public String estado { get; set; }
        @AuraEnabled public String nombreDonante { get; set; }
        @AuraEnabled public Boolean solicitaFactura { get; set; }
    }

    public class ResultadoConfirmacionDTO {
        @AuraEnabled public Boolean exito { get; set; }
        @AuraEnabled public String mensaje { get; set; }
        @AuraEnabled public String nuevoEstado { get; set; }
        @AuraEnabled public String tipoConfirmacion { get; set; }
    }

    /**
     * @description Obtiene el resumen de una donación para alimentar el modal de confirmación manual.
     * @param donacionId Identificador de Donacion__c.
     * @return DTO con datos esenciales de la donación.
     */
    @AuraEnabled(cacheable=true)
    public static ResumenConfirmacionDTO obtenerResumenDonacion(Id donacionId) {
        if (donacionId == null) {
            AuraHandledException ex = new AuraHandledException('El identificador de donación es obligatorio.');
            ex.setMessage('El identificador de donación es obligatorio.');
            throw ex;
        }

        List<Donacion__c> donaciones = [
            SELECT Id, Name, Campana__c, Campana__r.Name, Monto__c, Modalidad__c, Estado__c,
                   Nombre_Donante__c, Correo__c, Solicita_Factura__c, Tipo_Confirmacion__c
            FROM Donacion__c
            WHERE Id = :donacionId
            LIMIT 1
        ];

        if (donaciones.isEmpty()) {
            AuraHandledException ex = new AuraHandledException('No se encontró el registro de donación especificado.');
            ex.setMessage('No se encontró el registro de donación especificado.');
            throw ex;
        }

        Donacion__c don = donaciones[0];
        ResumenConfirmacionDTO dto = new ResumenConfirmacionDTO();
        dto.id = don.Id;
        dto.folio = don.Name;
        dto.campanaNombre = don.Campana__r != null ? don.Campana__r.Name : '';
        dto.monto = don.Monto__c;
        dto.modalidad = don.Modalidad__c;
        dto.estado = don.Estado__c;
        dto.nombreDonante = don.Nombre_Donante__c;
        dto.solicitaFactura = (don.Solicita_Factura__c == true);
        return dto;
    }

    /**
     * @description Confirma manualmente una donación en estado Pendiente, cambiando su estado a Pagada
     *              y su tipo a Manual. Dispara el trigger para recálculo y envío de comprobante (US-12).
     * @param donacionId Identificador de Donacion__c a confirmar.
     * @return Resultado de la operación con estado actualizado.
     */
    @AuraEnabled
    public static ResultadoConfirmacionDTO confirmarPagoManual(Id donacionId) {
        if (donacionId == null) {
            AuraHandledException ex = new AuraHandledException('El identificador de donación es obligatorio.');
            ex.setMessage('El identificador de donación es obligatorio.');
            throw ex;
        }

        List<Donacion__c> donaciones = [
            SELECT Id, Name, Estado__c, Tipo_Confirmacion__c
            FROM Donacion__c
            WHERE Id = :donacionId
            LIMIT 1
            FOR UPDATE
        ];

        if (donaciones.isEmpty()) {
            AuraHandledException ex = new AuraHandledException('No se encontró el registro de donación especificado.');
            ex.setMessage('No se encontró el registro de donación especificado.');
            throw ex;
        }

        Donacion__c don = donaciones[0];

        if (don.Estado__c == 'Pagada') {
            AuraHandledException ex = new AuraHandledException('Esta donación ya fue confirmada como Pagada previamente. No se permiten confirmaciones ni comprobantes duplicados.');
            ex.setMessage('Esta donación ya fue confirmada como Pagada previamente. No se permiten confirmaciones ni comprobantes duplicados.');
            throw ex;
        }

        if (don.Estado__c != 'Pendiente') {
            AuraHandledException ex = new AuraHandledException('Solo las donaciones en estado Pendiente pueden confirmarse manualmente.');
            ex.setMessage('Solo las donaciones en estado Pendiente pueden confirmarse manualmente.');
            throw ex;
        }

        don.Estado__c = 'Pagada';
        don.Tipo_Confirmacion__c = 'Manual';
        update don;

        ResultadoConfirmacionDTO resultado = new ResultadoConfirmacionDTO();
        resultado.exito = true;
        resultado.mensaje = 'Pago confirmado manualmente con éxito. Comprobante generado y enviado.';
        resultado.nuevoEstado = 'Pagada';
        resultado.tipoConfirmacion = 'Manual';
        return resultado;
    }
}
