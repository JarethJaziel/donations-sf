/**
 * @description Handler del trigger de Donacion__c: referencia pública, RFC y fecha de pago (before),
 *              y envío idempotente de comprobantes al pasar a Pagada (after) (US-05, US-06, US-08, US-12, US-16).
 *              El monto recaudado lo calcula el roll-up nativo Campana__c.Monto_Recaudado__c.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DonacionTriggerHandler {

    private static Set<Id> procesadosEnTransaccion = new Set<Id>();

    /**
     * @description Limpia la memoria de IDs procesados para permitir pruebas unitarias consecutivas.
     */
    @TestVisible
    private static void limpiarCacheTransaccion() {
        procesadosEnTransaccion.clear();
    }

    /**
     * @description Lógica before insert: referencia pública opaca, RFC normalizado y validado,
     *              y fecha de pago si el registro nace como Pagada (US-05, US-06 AC5).
     * @param newDonaciones Lista de registros en Trigger.new.
     */
    public static void beforeInsert(List<Donacion__c> newDonaciones) {
        if (newDonaciones == null) {
            return;
        }
        for (Donacion__c don : newDonaciones) {
            if (String.isBlank(don.Referencia_Publica__c)) {
                don.Referencia_Publica__c = UUID.randomUUID().toString();
            }
            prepararRfc(don);
            if (don.Estado__c == 'Pagada' && don.Fecha_Pago__c == null) {
                don.Fecha_Pago__c = System.now();
            }
        }
    }

    /**
     * @description Lógica before update: RFC normalizado y validado, y fecha de pago al pasar a Pagada.
     *              La referencia pública no se puede cambiar una vez asignada (US-06 AC5).
     * @param newDonaciones Lista de registros en Trigger.new.
     * @param oldMap Mapa de registros anteriores en Trigger.oldMap.
     */
    public static void beforeUpdate(List<Donacion__c> newDonaciones, Map<Id, Donacion__c> oldMap) {
        if (newDonaciones == null || oldMap == null) {
            return;
        }
        for (Donacion__c don : newDonaciones) {
            Donacion__c anterior = oldMap.get(don.Id);
            if (anterior == null) {
                continue;
            }
            if (String.isNotBlank(anterior.Referencia_Publica__c)
                && don.Referencia_Publica__c != anterior.Referencia_Publica__c) {
                don.Referencia_Publica__c.addError('La referencia pública no se puede modificar.');
            } else if (String.isBlank(don.Referencia_Publica__c)) {
                don.Referencia_Publica__c = UUID.randomUUID().toString();
            }
            prepararRfc(don);
            if (don.Estado__c == 'Pagada' && anterior.Estado__c != 'Pagada' && don.Fecha_Pago__c == null) {
                don.Fecha_Pago__c = System.now();
            }
        }
    }

    /**
     * @description Normaliza el RFC (sin espacios y en mayúsculas) y rechaza fechas inexistentes.
     *              Los errores de estructura los reporta la regla RFC_Valido_En_Modalidad_Factura.
     */
    private static void prepararRfc(Donacion__c don) {
        if (String.isBlank(don.RFC__c)) {
            return;
        }
        don.RFC__c = RfcValidator.normalizar(don.RFC__c);
        if (RfcValidator.tieneFormato(don.RFC__c) && !RfcValidator.esValido(don.RFC__c)) {
            don.RFC__c.addError('La fecha del RFC no existe (revisa año, mes y día).');
        }
    }

    /**
     * @description Lógica ejecutada en el evento after update de Donacion__c.
     * @param newDonaciones Lista de registros en Trigger.new.
     * @param oldMap Mapa de registros anteriores en Trigger.oldMap.
     */
    public static void afterUpdate(List<Donacion__c> newDonaciones, Map<Id, Donacion__c> oldMap) {
        if (newDonaciones == null || oldMap == null) {
            return;
        }

        Set<Id> idsParaComprobante = new Set<Id>();

        for (Donacion__c newDon : newDonaciones) {
            Donacion__c oldDon = oldMap.get(newDon.Id);
            if (oldDon == null) {
                continue;
            }

            Boolean cambioAPagada = (oldDon.Estado__c != 'Pagada' && newDon.Estado__c == 'Pagada');
            if (cambioAPagada && !newDon.Comprobante_Enviado__c && !procesadosEnTransaccion.contains(newDon.Id)) {
                procesadosEnTransaccion.add(newDon.Id);
                idsParaComprobante.add(newDon.Id);
            }
        }

        if (!idsParaComprobante.isEmpty()) {
            DonationReceiptService.enviarComprobantes(idsParaComprobante);
        }
    }
}
