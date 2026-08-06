@isTest
private class Test_SelectionService {

    static testMethod void testGetSelectionsForPlayerWeek() {
        Settings__c s = UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        List<Game__c> games = UnitTestUtils.createTestGames(s, 3);
        Player__c player = new Player__c(Name = 'Test Player', Nickname__c = 'TestP', Settings__c = s.Id);
        insert player;

        // Create some selections
        List<Selection__c> selections = new List<Selection__c>();
        selections.add(new Selection__c(Game__c = games[0].Id, Player__c = player.Id, Team__c = games[0].Home_Team__c));
        selections.add(new Selection__c(Game__c = games[1].Id, Player__c = player.Id, Team__c = games[1].Visiting_Team__c));
        insert selections;

        Test.startTest();
        SelectionService.SelectionsResult result = SelectionService.getSelectionsForPlayerWeek(player.Id, '1');
        Test.stopTest();

        System.assertEquals(3, result.numGames);
        System.assertEquals(2, result.numSelections);
        System.assertEquals(3, result.gameSelections.size());
        System.assertEquals(1, result.gameSelections[0].gameNumber);
        // Games have start time tomorrow, so not locked
        System.assertEquals(false, result.gameSelections[0].isLocked);
        System.assertNotEquals(null, result.gameSelections[0].selectedTeamId);
        System.assertEquals(null, result.gameSelections[2].selectedTeamId);
    }

    static testMethod void testGetSelectionsNoPlayer() {
        Settings__c s = UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        UnitTestUtils.createTestGames(s, 2);

        Test.startTest();
        SelectionService.SelectionsResult result = SelectionService.getSelectionsForPlayerWeek(null, '1');
        Test.stopTest();

        System.assertEquals(2, result.numGames);
        System.assertEquals(0, result.numSelections);
        System.assertEquals(0, result.totalPoints);
    }

    static testMethod void testSaveSelection() {
        Settings__c s = UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        List<Game__c> games = UnitTestUtils.createTestGames(s, 1);
        Player__c player = new Player__c(Name = 'Test Player', Nickname__c = 'TestP', Settings__c = s.Id);
        insert player;

        Test.startTest();
        SelectionService.saveSelection(games[0].Id, player.Id, games[0].Home_Team__c, false);
        Test.stopTest();

        List<Selection__c> saved = [SELECT Team__c FROM Selection__c WHERE Game__c = :games[0].Id AND Player__c = :player.Id];
        System.assertEquals(1, saved.size());
        System.assertEquals(games[0].Home_Team__c, saved[0].Team__c);
    }

    static testMethod void testSaveSelectionUpdate() {
        Settings__c s = UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        List<Game__c> games = UnitTestUtils.createTestGames(s, 1);
        Player__c player = new Player__c(Name = 'Test Player', Nickname__c = 'TestP', Settings__c = s.Id);
        insert player;

        // Create initial selection
        insert new Selection__c(Game__c = games[0].Id, Player__c = player.Id, Team__c = games[0].Home_Team__c);

        Test.startTest();
        // Change selection to visiting team
        SelectionService.saveSelection(games[0].Id, player.Id, games[0].Visiting_Team__c, false);
        Test.stopTest();

        List<Selection__c> saved = [SELECT Team__c FROM Selection__c WHERE Game__c = :games[0].Id AND Player__c = :player.Id];
        System.assertEquals(1, saved.size());
        System.assertEquals(games[0].Visiting_Team__c, saved[0].Team__c);
    }

    static testMethod void testSaveSelectionDeselect() {
        Settings__c s = UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        List<Game__c> games = UnitTestUtils.createTestGames(s, 1);
        Player__c player = new Player__c(Name = 'Test Player', Nickname__c = 'TestP', Settings__c = s.Id);
        insert player;

        // Create initial selection
        insert new Selection__c(Game__c = games[0].Id, Player__c = player.Id, Team__c = games[0].Home_Team__c);

        Test.startTest();
        // Deselecting (null team) should delete the underlying Selection__c record
        SelectionService.saveSelection(games[0].Id, player.Id, null, false);
        Test.stopTest();

        List<Selection__c> saved = [SELECT Id FROM Selection__c WHERE Game__c = :games[0].Id AND Player__c = :player.Id];
        System.assertEquals(0, saved.size());
    }

    static testMethod void testSaveSelectionDeselectNoExisting() {
        Settings__c s = UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        List<Game__c> games = UnitTestUtils.createTestGames(s, 1);
        Player__c player = new Player__c(Name = 'Test Player', Nickname__c = 'TestP', Settings__c = s.Id);
        insert player;

        Test.startTest();
        // Deselecting when there was never a selection should be a no-op, not an error
        SelectionService.saveSelection(games[0].Id, player.Id, null, false);
        Test.stopTest();

        List<Selection__c> saved = [SELECT Id FROM Selection__c WHERE Game__c = :games[0].Id AND Player__c = :player.Id];
        System.assertEquals(0, saved.size());
    }

    static testMethod void testSaveSelectionLockedGame() {
        Settings__c s = UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        List<Team__c> teams = [SELECT Id FROM Team__c ORDER BY Short_Name__c LIMIT 2];
        Game__c lockedGame = new Game__c(
            Week__c = '1',
            Home_Team__c = teams[0].Id,
            Visiting_Team__c = teams[1].Id,
            Start_Time__c = DateTime.now().addDays(-1),
            Spread__c = 3.0
        );
        insert lockedGame;
        Player__c player = new Player__c(Name = 'Test Player', Nickname__c = 'TestP', Settings__c = s.Id);
        insert player;

        Test.startTest();
        try {
            SelectionService.saveSelection(lockedGame.Id, player.Id, teams[0].Id, false);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('locked'));
        }
        Test.stopTest();
    }

    static testMethod void testSaveSelectionLockedGameAsAdmin() {
        Settings__c s = UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        List<Team__c> teams = [SELECT Id FROM Team__c ORDER BY Short_Name__c LIMIT 2];
        Game__c lockedGame = new Game__c(
            Week__c = '1',
            Home_Team__c = teams[0].Id,
            Visiting_Team__c = teams[1].Id,
            Start_Time__c = DateTime.now().addDays(-1),
            Spread__c = 3.0
        );
        insert lockedGame;
        Player__c player = new Player__c(Name = 'Test Player', Nickname__c = 'TestP', Settings__c = s.Id);
        insert player;

        Test.startTest();
        // Admin can save even when locked
        SelectionService.saveSelection(lockedGame.Id, player.Id, teams[0].Id, true);
        Test.stopTest();

        List<Selection__c> saved = [SELECT Team__c FROM Selection__c WHERE Game__c = :lockedGame.Id AND Player__c = :player.Id];
        System.assertEquals(1, saved.size());
    }

    static testMethod void testGetActivePlayers() {
        Settings__c s = UnitTestUtils.createTestSettings();
        User playerUser = UnitTestUtils.createTestUser();
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(adminUser) {
            insert playerUser;
            UnitTestUtils.createTestPlayer(playerUser, 'TestPlayer');
        }

        Test.startTest();
        List<Map<String, String>> players = SelectionService.getActivePlayers();
        Test.stopTest();

        System.assert(players.size() > 0);
        Boolean found = false;
        for (Map<String, String> p : players) {
            System.assertNotEquals(null, p.get('value'));
            System.assertNotEquals(null, p.get('label'));
            if (p.get('label').contains('tplayer123')) {
                found = true;
            }
        }
        System.assert(found, 'Test player should appear in active players list');
    }

    static testMethod void testGetCurrentPlayerIdForUser() {
        Settings__c s = UnitTestUtils.createTestSettings();
        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Player__c player = new Player__c(Name = 'Admin Player', Nickname__c = 'AdminP', Settings__c = s.Id, User__c = adminUser.Id);
        insert player;

        Test.startTest();
        String playerId = SelectionService.getCurrentPlayerIdForUser();
        Test.stopTest();

        System.assertEquals(player.Id, playerId);
    }

    static testMethod void testGetCurrentPlayerIdForUserNoPlayer() {
        UnitTestUtils.createTestSettings();

        Test.startTest();
        String playerId = SelectionService.getCurrentPlayerIdForUser();
        Test.stopTest();

        System.assertEquals(null, playerId);
    }
}
