@isTest
private class Test_ResultsService {

    static testMethod void testGetWeeklyResults() {
        TestScaffold s = new TestScaffold();

        // Delete unused players
        delete new List<Player__c>{ s.player3, s.player4, s.player5 };

        // Create 3 games
        List<Game__c> gameList = new List<Game__c>();
        Game__c g1 = new Game__c(Week__c = '1', Start_Time__c = DateTime.now(),
            Home_Team__c = s.niners.Id, Visiting_Team__c = s.bears.Id, Spread__c = 0.0);
        gameList.add(g1);
        Game__c g2 = new Game__c(Week__c = '1', Start_Time__c = DateTime.now(),
            Home_Team__c = s.bengals.Id, Visiting_Team__c = s.bills.Id, Spread__c = 0.0);
        gameList.add(g2);
        Game__c g3 = new Game__c(Week__c = '1', Start_Time__c = DateTime.now(),
            Home_Team__c = s.broncos.Id, Visiting_Team__c = s.browns.Id, Spread__c = 0.0);
        gameList.add(g3);
        insert gameList;

        // Player1 picks all winners, Player2 picks 2 of 3
        List<Selection__c> selections = new List<Selection__c>();
        selections.add(new Selection__c(Game__c = g1.Id, Player__c = s.player1.Id, Team__c = s.niners.Id));
        selections.add(new Selection__c(Game__c = g2.Id, Player__c = s.player1.Id, Team__c = s.bills.Id));
        selections.add(new Selection__c(Game__c = g3.Id, Player__c = s.player1.Id, Team__c = s.broncos.Id));
        selections.add(new Selection__c(Game__c = g1.Id, Player__c = s.player2.Id, Team__c = s.bears.Id));
        selections.add(new Selection__c(Game__c = g2.Id, Player__c = s.player2.Id, Team__c = s.bills.Id));
        selections.add(new Selection__c(Game__c = g3.Id, Player__c = s.player2.Id, Team__c = s.broncos.Id));
        insert selections;

        // Finalize games: Niners win, Bills win, Broncos win
        g1.Home_Score__c = 20; g1.Visiting_Score__c = 10; g1.Final__c = true;
        g2.Home_Score__c = 10; g2.Visiting_Score__c = 20; g2.Final__c = true;
        g3.Home_Score__c = 20; g3.Visiting_Score__c = 10; g3.Final__c = true;
        update gameList;

        Test.startTest();
        ResultsService.Results results = ResultsService.getWeeklyResults('1');
        Test.stopTest();

        System.assertEquals(3.0, results.pointsAvailable);
        System.assertEquals(2, results.resultRows.size());
        // Player1 is first (3 for 3)
        System.assertEquals('Player1', results.resultRows[0].nickname);
        System.assertEquals(3.0, results.resultRows[0].pointsScored);
        System.assertEquals(1.000, results.resultRows[0].winPercentage);
        // Player2 is second (2 for 3)
        System.assertEquals('Player2', results.resultRows[1].nickname);
        System.assertEquals(2.0, results.resultRows[1].pointsScored);
        System.assertEquals(0.667, results.resultRows[1].winPercentage);
    }

    static testMethod void testGetWeeklyResultsNoGames() {
        TestScaffold s = new TestScaffold();

        Test.startTest();
        ResultsService.Results results = ResultsService.getWeeklyResults('1');
        Test.stopTest();

        System.assertEquals(null, results.pointsAvailable);
        System.assertEquals(0, results.resultRows.size());
    }

    static testMethod void testGetSeasonalResults() {
        TestScaffold s = new TestScaffold();

        // Delete unused players
        delete new List<Player__c>{ s.player3, s.player4, s.player5 };

        // Create games and finalize
        List<Game__c> gameList = new List<Game__c>();
        Game__c g1 = new Game__c(Week__c = '1', Start_Time__c = DateTime.now(),
            Home_Team__c = s.niners.Id, Visiting_Team__c = s.bears.Id,
            Spread__c = 0.0, Home_Score__c = 20, Visiting_Score__c = 10, Final__c = true);
        gameList.add(g1);
        Game__c g2 = new Game__c(Week__c = '1', Start_Time__c = DateTime.now(),
            Home_Team__c = s.bengals.Id, Visiting_Team__c = s.bills.Id,
            Spread__c = 0.0, Home_Score__c = 10, Visiting_Score__c = 20, Final__c = true);
        gameList.add(g2);
        insert gameList;

        // Player1 picks both winners, Player2 picks 1 of 2
        List<Selection__c> selections = new List<Selection__c>();
        selections.add(new Selection__c(Game__c = g1.Id, Player__c = s.player1.Id, Team__c = s.niners.Id));
        selections.add(new Selection__c(Game__c = g2.Id, Player__c = s.player1.Id, Team__c = s.bills.Id));
        selections.add(new Selection__c(Game__c = g1.Id, Player__c = s.player2.Id, Team__c = s.bears.Id));
        selections.add(new Selection__c(Game__c = g2.Id, Player__c = s.player2.Id, Team__c = s.bills.Id));
        insert selections;

        Test.startTest();
        ResultsService.Results results = ResultsService.getSeasonalResults();
        Test.stopTest();

        System.assertEquals(2.0, results.pointsAvailable);
        System.assertEquals(2, results.resultRows.size());
        System.assertEquals('Player1', results.resultRows[0].nickname);
        System.assertEquals(2.0, results.resultRows[0].pointsScored);
    }

    private class TestScaffold {
        Settings__c settings;
        Team__c niners, bears, bengals, bills, broncos, browns;
        Player__c player1, player2, player3, player4, player5;

        TestScaffold() {
            settings = new Settings__c(Name = 'Pool Settings', NumberOfWeeks__c = 4, CurrentWeek__c = 1,
                MaxGames__c = 5, EntryFee__c = 50, UsernameSuffix__c = 'nflpool.com');
            insert settings;

            List<Team__c> teams = new List<Team__c>();
            niners = new Team__c(Name = 'San Francisco 49ers', Short_Name__c = '49ers');
            teams.add(niners);
            bears = new Team__c(Name = 'Chicago Bears', Short_Name__c = 'Bears');
            teams.add(bears);
            bengals = new Team__c(Name = 'Cincinnati Bengals', Short_Name__c = 'Bengals');
            teams.add(bengals);
            bills = new Team__c(Name = 'Buffalo Bills', Short_Name__c = 'Bills');
            teams.add(bills);
            broncos = new Team__c(Name = 'Denver Broncos', Short_Name__c = 'Broncos');
            teams.add(broncos);
            browns = new Team__c(Name = 'Cleveland Browns', Short_Name__c = 'Browns');
            teams.add(browns);
            insert teams;

            List<Player__c> players = new List<Player__c>();
            player1 = new Player__c(Name = 'Player One', Nickname__c = 'Player1', Settings__c = settings.Id);
            players.add(player1);
            player2 = new Player__c(Name = 'Player Two', Nickname__c = 'Player2', Settings__c = settings.Id);
            players.add(player2);
            player3 = new Player__c(Name = 'Player Three', Nickname__c = 'Player3', Settings__c = settings.Id);
            players.add(player3);
            player4 = new Player__c(Name = 'Player Four', Nickname__c = 'Player4', Settings__c = settings.Id);
            players.add(player4);
            player5 = new Player__c(Name = 'Player Five', Nickname__c = 'Player5', Settings__c = settings.Id);
            players.add(player5);
            insert players;
        }
    }
}
