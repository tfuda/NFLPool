@isTest
private class Test_SettingsService {

    static testMethod void testGetSettings() {
        Settings__c s = UnitTestUtils.createTestSettings();

        Test.startTest();
        Settings__c result = SettingsService.getSettings();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(s.Id, result.Id);
        System.assertEquals(1, result.CurrentWeek__c);
        System.assertEquals(17, result.NumberOfWeeks__c);
    }

    static testMethod void testIsCurrentUserAdmin() {
        UnitTestUtils.createTestSettings();

        Test.startTest();
        Boolean isAdmin = SettingsService.isCurrentUserAdmin();
        Test.stopTest();

        // Running as System Administrator in test context
        System.assertEquals(true, isAdmin);
    }

    static testMethod void testIsCurrentUserAdminAsFalse() {
        UnitTestUtils.createTestSettings();
        User playerUser = UnitTestUtils.createTestUser();
        insert playerUser;

        System.runAs(playerUser) {
            Test.startTest();
            Boolean isAdmin = SettingsService.isCurrentUserAdmin();
            Test.stopTest();

            System.assertEquals(false, isAdmin);
        }
    }

    static testMethod void testGetWeekNumbers() {
        UnitTestUtils.createTestSettings();

        Test.startTest();
        List<String> weeks = SettingsService.getWeekNumbers();
        Test.stopTest();

        System.assertEquals(17, weeks.size());
        System.assertEquals('1', weeks[0]);
        System.assertEquals('17', weeks[16]);
    }
}
