/**
 * @description Trigger sobre el objeto Donacion__c que delega eventos en DonacionTriggerHandler.
 */
trigger DonacionTrigger on Donacion__c (before insert, before update, after update) {
    if (Trigger.isBefore && Trigger.isInsert) {
        DonacionTriggerHandler.beforeInsert(Trigger.new);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        DonacionTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        DonacionTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
