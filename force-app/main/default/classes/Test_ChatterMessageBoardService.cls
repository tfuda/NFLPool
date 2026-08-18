@isTest
private class Test_ChatterMessageBoardService {

    static testMethod void testGetGroupIdByName() {
        CollaborationGroup grp = new CollaborationGroup(Name = 'Test Chatter Group', CollaborationType = 'Public');
        insert grp;

        Test.startTest();
        Id groupId = ChatterMessageBoardService.getGroupIdByName('Test Chatter Group');
        Test.stopTest();

        System.assertEquals(grp.Id, groupId);
    }

    static testMethod void testGetGroupIdByNameNotFound() {
        Test.startTest();
        Id groupId = ChatterMessageBoardService.getGroupIdByName('Nonexistent Group');
        Test.stopTest();

        System.assertEquals(null, groupId);
    }
}
