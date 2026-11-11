public with sharing class ChatterMessageBoardService {

    @AuraEnabled(cacheable=true)
    public static Id getGroupIdByName(String groupName) {
        List<CollaborationGroup> groups = [
            SELECT Id
            FROM CollaborationGroup
            WHERE Name = :groupName
            LIMIT 1
        ];
        return groups.isEmpty() ? null : groups[0].Id;
    }
}
