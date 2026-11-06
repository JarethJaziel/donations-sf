/**
 * @description Handler del trigger de Donacion__c encargado de orquestar el envío de comprobantes,
 *              la idempotencia de ejecución y el recálculo de montos en campañas (US-08, US-12, US-16).
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CognitiveComplexity, PMD.CyclomaticComplexity')
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
     * @description Lógica ejecutada en el evento after update de Donacion__c.
     * @param newDonaciones Lista de registros en Trigger.new.
     * @param oldMap Mapa de registros anteriores en Trigger.oldMap.
     */
    public static void afterUpdate(List<Donacion__c> newDonaciones, Map<Id, Donacion__c> oldMap) {
        if (newDonaciones == null || oldMap == null) {
            return;
        }

        Set<Id> idsParaComprobante = new Set<Id>();
        Set<Id> campanaIdsParaRecalcular = new Set<Id>();

        for (Donacion__c newDon : newDonaciones) {
            Donacion__c oldDon = oldMap.get(newDon.Id);
            if (oldDon == null) {
                continue;
            }

            Boolean cambioAPagada = (oldDon.Estado__c != 'Pagada' && newDon.Estado__c == 'Pagada');
            Boolean dejoDeSerPagada = (oldDon.Estado__c == 'Pagada' && newDon.Estado__c != 'Pagada');
            Boolean cambioMontoSiendoPagada = (newDon.Estado__c == 'Pagada' && oldDon.Monto__c != newDon.Monto__c);
            Boolean cambioCampana = (oldDon.Campana__c != newDon.Campana__c);

            if (cambioAPagada && !newDon.Comprobante_Enviado__c && !procesadosEnTransaccion.contains(newDon.Id)) {
                procesadosEnTransaccion.add(newDon.Id);
                idsParaComprobante.add(newDon.Id);
            }

            if (cambioAPagada || dejoDeSerPagada || cambioMontoSiendoPagada || cambioCampana) {
                if (newDon.Campana__c != null) {
                    campanaIdsParaRecalcular.add(newDon.Campana__c);
                }
                if (oldDon.Campana__c != null) {
                    campanaIdsParaRecalcular.add(oldDon.Campana__c);
                }
            }
        }

        if (!idsParaComprobante.isEmpty()) {
            DonationReceiptService.enviarComprobantes(idsParaComprobante);
        }

        if (!campanaIdsParaRecalcular.isEmpty()) {
            recalcularMontoRecaudadoCampanas(campanaIdsParaRecalcular);
        }
    }

    /**
     * @description Recalcula el monto recaudado de las campañas afectadas en caso de que
     *              el campo sea editable (Currency/Apex roll-up) sin interferir si es Summary nativo.
     * @param campanaIds Conjunto de identificadores de Campana__c.
     */
    public static void recalcularMontoRecaudadoCampanas(Set<Id> campanaIds) {
        if (campanaIds == null || campanaIds.isEmpty()) {
            return;
        }

        if (Schema.sObjectType.Campana__c.fields.Monto_Recaudado__c.isUpdateable()) {
            Map<Id, Decimal> totalPorCampana = new Map<Id, Decimal>();
            for (Id cId : campanaIds) {
                totalPorCampana.put(cId, 0.00);
            }

            for (AggregateResult ar : [
                SELECT Campana__c campanaId, SUM(Monto__c) totalRecaudado
                FROM Donacion__c
                WHERE Campana__c IN :campanaIds
                  AND Estado__c = 'Pagada'
                GROUP BY Campana__c
            ]) {
                Id cId = (Id) ar.get('campanaId');
                Decimal total = (Decimal) ar.get('totalRecaudado');
                totalPorCampana.put(cId, total != null ? total : 0.00);
            }

            List<Campana__c> campanasUpdate = new List<Campana__c>();
            for (Id cId : totalPorCampana.keySet()) {
                Campana__c c = new Campana__c(Id = cId);
                c.put('Monto_Recaudado__c', totalPorCampana.get(cId));
                campanasUpdate.add(c);
            }

            if (!campanasUpdate.isEmpty()) {
                update campanasUpdate;
            }
        }
    }
}
