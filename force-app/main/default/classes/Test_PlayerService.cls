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

            // The User updates below must stay inside this runAs block: mixing
            // DML on a setup object (User) with the earlier non-setup
            // Settings__c insert in the same transaction throws
            // MIXED_DML_OPERATION otherwise.
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

    static testMethod void testCreateUser() {
        Settings__c s = UnitTestUtils.createTestSettings();
        Profile p = [SELECT Id FROM Profile WHERE Name = :Constants.PLAYER_PROFILE];
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        String userId;
        System.runAs(adminUser) {
            // Must stay inside this runAs block -- inserting a User (setup
            // object) after the earlier non-setup Settings__c insert throws
            // MIXED_DML_OPERATION otherwise. This is the exact gap
            // createUser/updateUser exist to isolate: the LWC calls this as
            // its own round-trip, separate from savePlayerRecord.
            Test.startTest();
            userId = PlayerService.createUser(
                'Test', 'NewPlayer', 'test.newplayer@nflpool.com', 'newbie',
                'newplayer@test.com', '(222) 333-4444',
                '123 Main St', 'Stamford', 'CT', '06905',
                p.Id, true
            );
            Test.stopTest();
        }

        System.assertNotEquals(null, userId);
        User created = [SELECT FirstName, LastName, IsActive FROM User WHERE Id = :userId];
        System.assertEquals('Test', created.FirstName);
        System.assertEquals('NewPlayer', created.LastName);
        System.assertEquals(true, created.IsActive);
    }

    static testMethod void testUpdateUser() {
        Settings__c s = UnitTestUtils.createTestSettings();
        User playerUser = UnitTestUtils.createTestUser();
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        String resultId;
        System.runAs(adminUser) {
            insert playerUser;

            Test.startTest();
            resultId = PlayerService.updateUser(
                playerUser.Id, 'Updated', playerUser.LastName, playerUser.Username,
                'updatednick', playerUser.Email, playerUser.Phone,
                playerUser.Street, playerUser.City, playerUser.State, playerUser.PostalCode,
                playerUser.ProfileId, false
            );
            Test.stopTest();
        }

        System.assertEquals(playerUser.Id, resultId);
        User updated = [SELECT FirstName, CommunityNickname, IsActive FROM User WHERE Id = :playerUser.Id];
        System.assertEquals('Updated', updated.FirstName);
        System.assertEquals('updatednick', updated.CommunityNickname);
        System.assertEquals(false, updated.IsActive);
    }

    static testMethod void testSavePlayerRecordCreatesWhenNoPlayerExists() {
        Settings__c s = UnitTestUtils.createTestSettings();
        User playerUser = UnitTestUtils.createTestUser();
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Id playerId;
        System.runAs(adminUser) {
            insert playerUser;

            Test.startTest();
            playerId = PlayerService.savePlayerRecord(playerUser.Id);
            Test.stopTest();
        }

        System.assertNotEquals(null, playerId);
        Player__c created = [SELECT User__c, Nickname__c FROM Player__c WHERE Id = :playerId];
        System.assertEquals(playerUser.Id, created.User__c);
        System.assertEquals(playerUser.CommunityNickname, created.Nickname__c);
    }

    static testMethod void testSavePlayerRecordUpdatesWhenPlayerExists() {
        Settings__c s = UnitTestUtils.createTestSettings();
        User playerUser = UnitTestUtils.createTestUser();
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Player__c existing;

        System.runAs(adminUser) {
            insert playerUser;
            existing = UnitTestUtils.createTestPlayer(playerUser, 'OldNick');

            // Re-sync from a changed User to prove savePlayerRecord takes the
            // update branch (not create) when a Player__c row already exists.
            playerUser.CommunityNickname = 'NewNick';
            update playerUser;

            Test.startTest();
            Id playerId = PlayerService.savePlayerRecord(playerUser.Id);
            Test.stopTest();

            System.assertEquals(existing.Id, playerId);
        }

        Player__c updated = [SELECT Nickname__c FROM Player__c WHERE Id = :existing.Id];
        System.assertEquals('NewNick', updated.Nickname__c);
    }
}
