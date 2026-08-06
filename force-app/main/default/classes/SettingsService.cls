public with sharing class SettingsService {

    @AuraEnabled(cacheable=true)
    public static Settings__c getSettings() {
        return PoolManagerUtils.getSettings();
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isCurrentUserAdmin() {
        List<Profile> adminProfiles = [
            SELECT Id FROM Profile
            WHERE Name = :Constants.SYSTEM_ADMIN_PROFILE
            OR Name = :Constants.POOL_ADMIN_PROFILE
        ];
        for (Profile p : adminProfiles) {
            if (p.Id == UserInfo.getProfileId()) {
                return true;
            }
        }
        return false;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getWeekNumbers() {
        Settings__c settings = PoolManagerUtils.getSettings();
        Integer numberOfWeeks = settings.NumberOfWeeks__c.intValue();
        List<String> weeks = new List<String>();
        for (Integer i = 1; i <= numberOfWeeks; i++) {
            weeks.add(i.format());
        }
        return weeks;
    }
}
