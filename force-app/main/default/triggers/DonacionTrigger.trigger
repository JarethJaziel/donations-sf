/**
 * @description Trigger sobre el objeto Donacion__c que delega eventos en DonacionTriggerHandler.
 */
trigger DonacionTrigger on Donacion__c (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        DonacionTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
