@isTest
private class Test_GameService {

    static testMethod void testGetGamesForWeek() {
        Settings__c s = UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        List<Game__c> games = UnitTestUtils.createTestGames(s, 3);

        Test.startTest();
        List<GameService.GameWrapper> wrappers = GameService.getGamesForWeek('1');
        Test.stopTest();

        System.assertEquals(3, wrappers.size());
        System.assertEquals(1, wrappers[0].gameNumber);
        System.assertEquals(2, wrappers[1].gameNumber);
        System.assertEquals(3, wrappers[2].gameNumber);
        // Games created with start time tomorrow, so not locked
        System.assertEquals(false, wrappers[0].isLocked);
    }

    static testMethod void testGetGamesForWeekEmpty() {
        UnitTestUtils.createTestSettings();

        Test.startTest();
        List<GameService.GameWrapper> wrappers = GameService.getGamesForWeek('1');
        Test.stopTest();

        System.assertEquals(0, wrappers.size());
    }

    static testMethod void testGetGamesForWeekLocked() {
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

        Test.startTest();
        List<GameService.GameWrapper> wrappers = GameService.getGamesForWeek('1');
        Test.stopTest();

        System.assertEquals(1, wrappers.size());
        System.assertEquals(true, wrappers[0].isLocked);
    }

    static testMethod void testSaveGames() {
        Settings__c s = UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        List<Team__c> teams = [SELECT Id, Short_Name__c FROM Team__c ORDER BY Short_Name__c];

        List<Game__c> games = new List<Game__c>();
        games.add(new Game__c(
            Week__c = '1',
            Home_Team__c = teams[0].Id,
            Visiting_Team__c = teams[1].Id,
            Start_Time__c = DateTime.now().addDays(1),
            Spread__c = 3.0
        ));
        games.add(new Game__c(
            Week__c = '1',
            Home_Team__c = teams[2].Id,
            Visiting_Team__c = teams[3].Id,
            Start_Time__c = DateTime.now().addDays(1),
            Spread__c = -2.5
        ));

        Test.startTest();
        List<GameService.GameWrapper> result = GameService.saveGames(games);
        Test.stopTest();

        System.assertEquals(2, result.size());
        System.assertNotEquals(null, result[0].game.Id);
    }

    static testMethod void testSaveGamesValidationError() {
        UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();

        // Game with missing teams
        List<Game__c> games = new List<Game__c>();
        games.add(new Game__c(Week__c = '1'));

        Test.startTest();
        try {
            GameService.saveGames(games);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('must set both home and visiting team'));
        }
        Test.stopTest();
    }

    static testMethod void testSaveGamesScoreValidation() {
        UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        List<Team__c> teams = [SELECT Id FROM Team__c ORDER BY Short_Name__c LIMIT 2];

        List<Game__c> games = new List<Game__c>();
        games.add(new Game__c(
            Week__c = '1',
            Home_Team__c = teams[0].Id,
            Visiting_Team__c = teams[1].Id,
            Home_Score__c = 100,
            Spread__c = 3.0
        ));

        Test.startTest();
        try {
            GameService.saveGames(games);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Home score must be between 0 and 99'));
        }
        Test.stopTest();
    }

    static testMethod void testSaveGamesFinalValidation() {
        UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        List<Team__c> teams = [SELECT Id FROM Team__c ORDER BY Short_Name__c LIMIT 2];

        List<Game__c> games = new List<Game__c>();
        games.add(new Game__c(
            Week__c = '1',
            Home_Team__c = teams[0].Id,
            Visiting_Team__c = teams[1].Id,
            Final__c = true
        ));

        Test.startTest();
        try {
            GameService.saveGames(games);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('To finalize'));
        }
        Test.stopTest();
    }

    static testMethod void testSaveGamesDuplicateTeam() {
        UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        List<Team__c> teams = [SELECT Id FROM Team__c ORDER BY Short_Name__c LIMIT 3];

        List<Game__c> games = new List<Game__c>();
        games.add(new Game__c(
            Week__c = '1',
            Home_Team__c = teams[0].Id,
            Visiting_Team__c = teams[1].Id,
            Spread__c = 3.0
        ));
        // Reuse teams[0] in second game
        games.add(new Game__c(
            Week__c = '1',
            Home_Team__c = teams[0].Id,
            Visiting_Team__c = teams[2].Id,
            Spread__c = 3.0
        ));

        Test.startTest();
        try {
            GameService.saveGames(games);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('already been assigned'));
        }
        Test.stopTest();
    }

    static testMethod void testDeleteGame() {
        Settings__c s = UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        List<Game__c> games = UnitTestUtils.createTestGames(s, 2);

        Test.startTest();
        List<GameService.GameWrapper> result = GameService.deleteGame(games[0].Id, '1');
        Test.stopTest();

        System.assertEquals(1, result.size());
    }

    static testMethod void testDeleteGameWithSelections() {
        Settings__c s = UnitTestUtils.createTestSettings();
        UnitTestUtils.createTestTeams();
        List<Game__c> games = UnitTestUtils.createTestGames(s, 1);
        Player__c player = new Player__c(Name = 'Test', Nickname__c = 'Test', Settings__c = s.Id);
        insert player;
        insert new Selection__c(Game__c = games[0].Id, Player__c = player.Id);

        Test.startTest();
        try {
            GameService.deleteGame(games[0].Id, '1');
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('selections reference'));
        }
        Test.stopTest();
    }

    static testMethod void testGetTeamOptions() {
        UnitTestUtils.createTestTeams();

        Test.startTest();
        List<Map<String, String>> options = GameService.getTeamOptions();
        Test.stopTest();

        System.assert(options.size() > 0);
        System.assertNotEquals(null, options[0].get('value'));
        System.assertNotEquals(null, options[0].get('label'));
    }
}
