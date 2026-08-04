@isTest
private class Test_PlayerService {

    static testMethod void testGetPlayer() {
        Settings__c s = UnitTestUtils.createTestSettings();
        User playerUser = UnitTestUtils.createTestUser();
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(adminUser) {
            insert playerUser;
            Player__c player = UnitTestUtils.createTestPlayer(playerUser, 'TestPlayer');
        }

        Test.startTest();
        PlayerService.PlayerDetail detail = PlayerService.getPlayer(playerUser.Id);
        Test.stopTest();

        System.assertNotEquals(null, detail);
        System.assertNotEquals(null, detail.usr);
        System.assertNotEquals(null, detail.player);
        System.assertEquals(playerUser.Id, detail.usr.Id);
        System.assertNotEquals(null, detail.payments);
    }

    static testMethod void testGetPlayerCurrentUser() {
        Settings__c s = UnitTestUtils.createTestSettings();
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Player__c player = new Player__c(Name = 'Admin', Nickname__c = 'Admin', Settings__c = s.Id, User__c = adminUser.Id);
        insert player;

        Test.startTest();
        PlayerService.PlayerDetail detail = PlayerService.getPlayer(null);
        Test.stopTest();

        System.assertNotEquals(null, detail);
        System.assertEquals(adminUser.Id, detail.usr.Id);
    }

    static testMethod void testGetProfileOptions() {
        Test.startTest();
        List<Map<String, String>> options = PlayerService.getProfileOptions();
        Test.stopTest();

        System.assert(options.size() > 0);
        for (Map<String, String> opt : options) {
            System.assertNotEquals(null, opt.get('value'));
            System.assertNotEquals(null, opt.get('label'));
        }
    }

    static testMethod void testSavePayment() {
        Settings__c s = UnitTestUtils.createTestSettings();
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Player__c player = new Player__c(Name = 'Admin', Nickname__c = 'Admin', Settings__c = s.Id, User__c = adminUser.Id);
        insert player;

        PlayerPayment__c payment = new PlayerPayment__c(
            Player__c = player.Id,
            Amount__c = 50.00,
            PaymentDate__c = Date.today()
        );

        Test.startTest();
        PlayerPayment__c result = PlayerService.savePayment(payment, 150.00);
        Test.stopTest();

        System.assertNotEquals(null, result.Id);
        System.assertEquals(50.00, result.Amount__c);
    }

    static testMethod void testSavePaymentExceedsBalance() {
        Settings__c s = UnitTestUtils.createTestSettings();
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Player__c player = new Player__c(Name = 'Admin', Nickname__c = 'Admin', Settings__c = s.Id, User__c = adminUser.Id);
        insert player;

        PlayerPayment__c payment = new PlayerPayment__c(
            Player__c = player.Id,
            Amount__c = 200.00,
            PaymentDate__c = Date.today()
        );

        Test.startTest();
        try {
            PlayerService.savePayment(payment, 150.00);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('greater than the balance due'));
        }
        Test.stopTest();
    }

    static testMethod void testDeletePayment() {
        Settings__c s = UnitTestUtils.createTestSettings();
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Player__c player = new Player__c(Name = 'Admin', Nickname__c = 'Admin', Settings__c = s.Id, User__c = adminUser.Id);
        insert player;
        PlayerPayment__c payment = new PlayerPayment__c(
            Player__c = player.Id,
            Amount__c = 50.00,
            PaymentDate__c = Date.today()
        );
        insert payment;

        Test.startTest();
        PlayerService.deletePayment(payment.Id);
        Test.stopTest();

        List<PlayerPayment__c> remaining = [SELECT Id FROM PlayerPayment__c WHERE Id = :payment.Id];
        System.assertEquals(0, remaining.size());
    }

    static testMethod void testGetPlayerList() {
        Settings__c s = UnitTestUtils.createTestSettings();
        User playerUser = UnitTestUtils.createTestUser();
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(adminUser) {
            insert playerUser;
            UnitTestUtils.createTestPlayer(playerUser, 'TestPlayer');
        }

        Test.startTest();
        List<PlayerService.PlayerDetail> allPlayers = PlayerService.getPlayerList(false);
        List<PlayerService.PlayerDetail> activePlayers = PlayerService.getPlayerList(true);
        Test.stopTest();

        System.assert(allPlayers.size() > 0);
        System.assert(activePlayers.size() > 0);
        // Active list should be <= all list
        System.assert(activePlayers.size() <= allPlayers.size());
    }

    static testMethod void testActivateDeactivateUser() {
        Settings__c s = UnitTestUtils.createTestSettings();
        User playerUser = UnitTestUtils.createTestUser();
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(adminUser) {
            insert playerUser;
        }

        Test.startTest();
        PlayerService.deactivateUser(playerUser.Id);
        User deactivated = [SELECT IsActive FROM User WHERE Id = :playerUser.Id];
        System.assertEquals(false, deactivated.IsActive);

        PlayerService.activateUser(playerUser.Id);
        User activated = [SELECT IsActive FROM User WHERE Id = :playerUser.Id];
        System.assertEquals(true, activated.IsActive);
        Test.stopTest();
    }
}
