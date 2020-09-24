trigger Player on Player__c (before insert) {

    Settings__c settings = PoolManagerUtils.getSettings();

    for (Player__c player : Trigger.new) {
        player.Settings__c = settings.Id;
    }
}