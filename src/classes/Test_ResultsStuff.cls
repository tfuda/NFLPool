/**
 * Unit tests for the GameChange trigger and for the ResultsController
 */
@isTest
private class Test_ResultsStuff {

    static testMethod void testGameChangeTrigger() {
        Scaffold s = new Scaffold();
        
        // First, make sure there are no Weekly Result objects for week 1
        List<Weekly_Result__c> wrList = [SELECT Id, Week__c, Player__c, 
        	Total_Points_Available__c, Total_Points__c, Win_Percentage__c
        	FROM Weekly_Result__c WHERE Week__c = '1'];
        System.assertEquals(0, wrList.size());
        
        // Add three games, not final yet
        List<Game__c> gameList = new List<Game__c>();
        s.ninersVsBears = new Game__c(Week__c='1', Start_Time__c=DateTime.now(), 
        	Home_Team__c=s.niners.Id, Visiting_Team__c=s.bears.Id, Spread__c=0.0);
        gameList.add(s.ninersVsBears);
        s.bengalsVsBills = new Game__c(Week__c='1', Start_Time__c=DateTime.now(), 
        	Home_Team__c=s.bengals.Id, Visiting_Team__c=s.bills.Id, Spread__c=0.0);
        gameList.add(s.bengalsVsBills);
        s.broncosVsBrowns = new Game__c(Week__c='1', Start_Time__c=DateTime.now(), 
        	Home_Team__c=s.broncos.Id, Visiting_Team__c=s.browns.Id, Spread__c=0.0);
        gameList.add(s.broncosVsBrowns);
        insert gameList;
        
        // There still should not be any Weekly Result objects for week 1 because the games arent final
        wrList = [SELECT Id, Week__c, Player__c, 
        	Total_Points_Available__c, Total_Points__c, Win_Percentage__c
        	FROM Weekly_Result__c WHERE Week__c = '1'];
        System.assertEquals(0, wrList.size());
        
        // Create player selections for players 1 and 2
        List<Selection__c> selectionList = new List<Selection__c>();
        Selection__c sel11 = new Selection__c(Game__c=s.ninersVsBears.Id, Player__c=s.player1.Id, Team__c=s.niners.Id);
        selectionList.add(sel11);
        Selection__c sel12 = new Selection__c(Game__c=s.bengalsVsBills.Id, Player__c=s.player1.Id, Team__c=s.bills.Id);
        selectionList.add(sel12);
        Selection__c sel13 = new Selection__c(Game__c=s.broncosVsBrowns.Id, Player__c=s.player1.Id, Team__c=s.broncos.Id);
        selectionList.add(sel13);
        Selection__c sel21 = new Selection__c(Game__c=s.ninersVsBears.Id, Player__c=s.player2.Id, Team__c=s.bears.Id);
        selectionList.add(sel21);
        Selection__c sel22 = new Selection__c(Game__c=s.bengalsVsBills.Id, Player__c=s.player2.Id, Team__c=s.bills.Id);
        selectionList.add(sel22);
        Selection__c sel23 = new Selection__c(Game__c=s.broncosVsBrowns.Id, Player__c=s.player2.Id, Team__c=s.broncos.Id);
        selectionList.add(sel23);
        insert selectionList;
        
        // Update the games to set a score and make them finals
        // Niners win
        s.ninersVsBears.Home_Score__c=20;
        s.ninersVsBears.Visiting_Score__c=10;
        s.ninersVsBears.Final__c = true;
        // Bills win
        s.bengalsVsBills.Home_Score__c=10;
        s.bengalsVsBills.Visiting_Score__c=20;
        s.bengalsVsBills.Final__c = true;
        // Broncos win
        s.broncosVsBrowns.Home_Score__c=20;
        s.broncosVsBrowns.Visiting_Score__c=10;
        s.broncosVsBrowns.Final__c = true;
        update gameList;
        
        // There should be two Weekly Result objects for week 1 because the games arent final
        wrList = [SELECT Id, Week__c, Player__c, 
        	Total_Points_Available__c, Total_Points__c, Win_Percentage__c
        	FROM Weekly_Result__c WHERE Week__c = '1' 
        	ORDER BY Player__r.Nickname__c];
        System.assertEquals(2, wrList.size());
        // Check Player1's results
        System.assertEquals('1', wrList[0].Week__c);
        System.assertEquals(s.player1.Id, wrList[0].Player__c);
        System.assertEquals(3.0, wrList[0].Total_Points_Available__c);
        // Player1 went 3 for 3
        System.assertEquals(3.0, wrList[0].Total_Points__c);
        System.assertEquals(1.0, wrList[0].Win_Percentage__c);
        // Check Player2's results
        System.assertEquals('1', wrList[1].Week__c);
        System.assertEquals(s.player2.Id, wrList[1].Player__c);
        System.assertEquals(3.0, wrList[1].Total_Points_Available__c);
        // Player2 went 2 for 3
        System.assertEquals(2.0, wrList[1].Total_Points__c);
        System.assertEquals(0.667, wrList[1].Win_Percentage__c);
        
        // Add two more games
        s.bucsVsCards = new Game__c(Week__c='1', Start_Time__c=DateTime.now(), 
        	Home_Team__c=s.bucs.Id, Visiting_Team__c=s.cards.Id, Spread__c=0.0);
        gameList.add(s.bucsVsCards);
        s.chargersVsChiefs = new Game__c(Week__c='1', Start_Time__c=DateTime.now(), 
        	Home_Team__c=s.chargers.Id, Visiting_Team__c=s.chiefs.Id, Spread__c=0.0);
        gameList.add(s.chargersVsChiefs);
        upsert gameList;
        
        // These should have no effect on the Weekly Result yet
        wrList = [SELECT Id, Week__c, Player__c, 
        	Total_Points_Available__c, Total_Points__c, Win_Percentage__c
        	FROM Weekly_Result__c WHERE Week__c = '1' 
        	ORDER BY Player__r.Nickname__c];
        System.assertEquals(2, wrList.size());
        // Check Player1's results
        System.assertEquals('1', wrList[0].Week__c);
        System.assertEquals(s.player1.Id, wrList[0].Player__c);
        System.assertEquals(3.0, wrList[0].Total_Points_Available__c);
        // Player1 went 3 for 3
        System.assertEquals(3.0, wrList[0].Total_Points__c);
        System.assertEquals(1.0, wrList[0].Win_Percentage__c);
        // Check Player2's results
        System.assertEquals('1', wrList[1].Week__c);
        System.assertEquals(s.player2.Id, wrList[1].Player__c);
        System.assertEquals(3.0, wrList[1].Total_Points_Available__c);
        // Player1 went 2 for 3
        System.assertEquals(2.0, wrList[1].Total_Points__c);
        System.assertEquals(0.667, wrList[1].Win_Percentage__c);
        
        // Add selections for these two games
		selectionList = new List<Selection__c>();
        Selection__c sel14 = new Selection__c(Game__c=s.bucsVsCards.Id, Player__c=s.player1.Id, Team__c=s.bucs.Id);
        selectionList.add(sel14);
        Selection__c sel15 = new Selection__c(Game__c=s.chargersVsChiefs.Id, Player__c=s.player1.Id, Team__c=s.chiefs.Id);
        selectionList.add(sel15);
        Selection__c sel24 = new Selection__c(Game__c=s.bucsVsCards.Id, Player__c=s.player2.Id, Team__c=s.bucs.Id);
        selectionList.add(sel24);
        Selection__c sel25 = new Selection__c(Game__c=s.chargersVsChiefs.Id, Player__c=s.player2.Id, Team__c=s.chargers.Id);
        selectionList.add(sel25);
        insert selectionList;
        
        // Cards win
        s.bucsVsCards.Home_Score__c = 10;
        s.bucsVsCards.Visiting_Score__c = 20;
        s.bucsVsCards.Final__c = true;
        // Chiefs win
        s.chargersVsChiefs.Home_Score__c = 10;
        s.chargersVsChiefs.Visiting_Score__c = 20;
        s.chargersVsChiefs.Final__c = true;
        upsert gameList;
        
        // Check the results again
        wrList = [SELECT Id, Week__c, Player__c, 
        	Total_Points_Available__c, Total_Points__c, Win_Percentage__c
        	FROM Weekly_Result__c WHERE Week__c = '1' 
        	ORDER BY Player__r.Nickname__c];
        System.assertEquals(2, wrList.size());
        // Check Player1's results
        System.assertEquals('1', wrList[0].Week__c);
        System.assertEquals(s.player1.Id, wrList[0].Player__c);
        System.assertEquals(5.0, wrList[0].Total_Points_Available__c);
        // Player1 went 4 for 5
        System.assertEquals(4.0, wrList[0].Total_Points__c);
        System.assertEquals(0.800, wrList[0].Win_Percentage__c);
        // Check Player2's results
        System.assertEquals('1', wrList[1].Week__c);
        System.assertEquals(s.player2.Id, wrList[1].Player__c);
        System.assertEquals(5.0, wrList[1].Total_Points_Available__c);
        // Player1 went 2 for 5
        System.assertEquals(2.0, wrList[1].Total_Points__c);
        System.assertEquals(0.400, wrList[1].Win_Percentage__c);
        
        // Add selections for a new player
        selectionList = new List<Selection__c>();
        Selection__c sel31 = new Selection__c(Game__c=s.ninersVsBears.Id, Player__c=s.player3.Id, Team__c=s.niners.Id);
        selectionList.add(sel31);
        Selection__c sel32 = new Selection__c(Game__c=s.bengalsVsBills.Id, Player__c=s.player3.Id, Team__c=s.bills.Id);
        selectionList.add(sel32);
        Selection__c sel33 = new Selection__c(Game__c=s.broncosVsBrowns.Id, Player__c=s.player3.Id, Team__c=s.broncos.Id);
        selectionList.add(sel33);
        Selection__c sel34 = new Selection__c(Game__c=s.bucsVsCards.Id, Player__c=s.player3.Id, Team__c=s.bucs.Id);
        selectionList.add(sel34);
        Selection__c sel35 = new Selection__c(Game__c=s.chargersVsChiefs.Id, Player__c=s.player3.Id, Team__c=s.chiefs.Id);
        selectionList.add(sel35);
        insert selectionList;
        
        // Delete a single game
        Id savedId = s.chargersVsChiefs.Id;
        delete s.chargersVsChiefs;
                
        // Check the results again
        wrList = [SELECT Id, Week__c, Player__c, 
        	Total_Points_Available__c, Total_Points__c, Win_Percentage__c
        	FROM Weekly_Result__c WHERE Week__c = '1' 
        	ORDER BY Player__r.Nickname__c];
        // There should now be three
        System.assertEquals(3, wrList.size());
        // Check Player1's results
        System.assertEquals('1', wrList[0].Week__c);
        System.assertEquals(s.player1.Id, wrList[0].Player__c);
        System.assertEquals(4.0, wrList[0].Total_Points_Available__c);
        // Player1 went 3 for 4
        System.assertEquals(3.0, wrList[0].Total_Points__c);
        System.assertEquals(0.750, wrList[0].Win_Percentage__c);
        // Check Player2's results
        System.assertEquals('1', wrList[1].Week__c);
        System.assertEquals(s.player2.Id, wrList[1].Player__c);
        System.assertEquals(4.0, wrList[1].Total_Points_Available__c);
        // Player2 went 2 for 4
        System.assertEquals(2.0, wrList[1].Total_Points__c);
        System.assertEquals(0.500, wrList[1].Win_Percentage__c);
        // Check Player3's results
        System.assertEquals('1', wrList[2].Week__c);
        System.assertEquals(s.player3.Id, wrList[2].Player__c);
        System.assertEquals(4.0, wrList[2].Total_Points_Available__c);
        // Player3 went 3 for 4, same as Player1
        System.assertEquals(3.0, wrList[2].Total_Points__c);
        System.assertEquals(0.750, wrList[2].Win_Percentage__c);
        
        // Undelete the game
        Game__c restoredGame = new Game__c(Id=savedId);
        undelete restoredGame;
        
        // Check the results again
        wrList = [SELECT Id, Week__c, Player__c, 
        	Total_Points_Available__c, Total_Points__c, Win_Percentage__c
        	FROM Weekly_Result__c WHERE Week__c = '1' 
        	ORDER BY Player__r.Nickname__c];
        System.assertEquals(3, wrList.size());
        // Check Player1's results
        System.assertEquals('1', wrList[0].Week__c);
        System.assertEquals(s.player1.Id, wrList[0].Player__c);
        System.assertEquals(5.0, wrList[0].Total_Points_Available__c);
        // Player1 went 4 for 5
        System.assertEquals(4.0, wrList[0].Total_Points__c);
        System.assertEquals(0.800, wrList[0].Win_Percentage__c);
        // Check Player2's results
        System.assertEquals('1', wrList[1].Week__c);
        System.assertEquals(s.player2.Id, wrList[1].Player__c);
        System.assertEquals(5.0, wrList[1].Total_Points_Available__c);
        // Player1 went 2 for 5
        System.assertEquals(2.0, wrList[1].Total_Points__c);
        System.assertEquals(0.400, wrList[1].Win_Percentage__c);
        // Check Player3's results
        System.assertEquals('1', wrList[2].Week__c);
        System.assertEquals(s.player3.Id, wrList[2].Player__c);
        System.assertEquals(5.0, wrList[2].Total_Points_Available__c);
        // Player3 went 4 for 5, same as Player1
        System.assertEquals(4.0, wrList[2].Total_Points__c);
        System.assertEquals(0.800, wrList[2].Win_Percentage__c);
        
        // Now delete all of the games for week 1
        List<Game__c> allGames = [SELECT Id FROM Game__c WHERE Week__c = '1'];
        delete allGames;
        
        // Verify that there are no Weekly Results for Week 1
        wrList = [SELECT Id, Week__c, Player__c, 
        	Total_Points_Available__c, Total_Points__c, Win_Percentage__c
        	FROM Weekly_Result__c WHERE Week__c = '1'];
        System.assertEquals(0, wrList.size());
        
    }
    
    static testMethod void testResultsController() {
        Scaffold s = new Scaffold();
        
        // Delete players we're not going to use for this test so they don't throw off the results
        delete s.player3;
        delete s.player4;
        delete s.player5;
        
        // Add three games for week 1 and week 2.
        List<Game__c> gameList = new List<Game__c>();
        s.ninersVsBears = new Game__c(Week__c='1', Start_Time__c=DateTime.now(), 
        	Home_Team__c=s.niners.Id, Visiting_Team__c=s.bears.Id, Spread__c=0.0);
        gameList.add(s.ninersVsBears);
        s.bengalsVsBills = new Game__c(Week__c='1', Start_Time__c=DateTime.now(), 
        	Home_Team__c=s.bengals.Id, Visiting_Team__c=s.bills.Id, Spread__c=0.0);
        gameList.add(s.bengalsVsBills);
        s.broncosVsBrowns = new Game__c(Week__c='1', Start_Time__c=DateTime.now(), 
        	Home_Team__c=s.broncos.Id, Visiting_Team__c=s.browns.Id, Spread__c=0.0);
        gameList.add(s.broncosVsBrowns);
        insert gameList;
        
        // Create player selections for players 1 and 2
        List<Selection__c> selectionList = new List<Selection__c>();
        Selection__c sel11 = new Selection__c(Game__c=s.ninersVsBears.Id, Player__c=s.player1.Id, Team__c=s.niners.Id);
        selectionList.add(sel11);
        Selection__c sel12 = new Selection__c(Game__c=s.bengalsVsBills.Id, Player__c=s.player1.Id, Team__c=s.bills.Id);
        selectionList.add(sel12);
        Selection__c sel13 = new Selection__c(Game__c=s.broncosVsBrowns.Id, Player__c=s.player1.Id, Team__c=s.broncos.Id);
        selectionList.add(sel13);
        Selection__c sel21 = new Selection__c(Game__c=s.ninersVsBears.Id, Player__c=s.player2.Id, Team__c=s.bears.Id);
        selectionList.add(sel21);
        Selection__c sel22 = new Selection__c(Game__c=s.bengalsVsBills.Id, Player__c=s.player2.Id, Team__c=s.bills.Id);
        selectionList.add(sel22);
        Selection__c sel23 = new Selection__c(Game__c=s.broncosVsBrowns.Id, Player__c=s.player2.Id, Team__c=s.broncos.Id);
        selectionList.add(sel23);
        insert selectionList;
        
        // Update the games to set a score and make them finals
        // Niners win
        s.ninersVsBears.Home_Score__c=20;
        s.ninersVsBears.Visiting_Score__c=10;
        s.ninersVsBears.Final__c = true;
        // Bills win
        s.bengalsVsBills.Home_Score__c=10;
        s.bengalsVsBills.Visiting_Score__c=20;
        s.bengalsVsBills.Final__c = true;
        // Broncos win
        s.broncosVsBrowns.Home_Score__c=20;
        s.broncosVsBrowns.Visiting_Score__c=10;
        s.broncosVsBrowns.Final__c = true;
        update gameList;

		// Instantiate the ResultsController
		System.Test.setCurrentPage(Page.Results);
		ResultsController con = new ResultsController();
		System.assertEquals('1', con.currentWeek);
		System.assertEquals('1', con.selectedWeek);
		System.assertEquals(1, con.weeks.size());
		System.assertEquals('1', con.weeks[0]);
		
		// Get the results for week 1
		ResultsController.Results results = ResultsController.getWeeklyResults('1');
		System.assertEquals(3.0, results.pointsAvailable);
		System.assertEquals(2, results.rWrappers.size());
		// Player 1 should be first (3 for 3), player 2 second (2 for 3)
		ResultsController.ResultWrapper r = results.rWrappers[0];
		System.assertEquals('Player1', r.nickname);
		System.assertEquals(3.0, r.pointsScored);
		System.assertEquals(1.000, r.winPercentage);
		r = results.rWrappers[1];
		System.assertEquals('Player2', r.nickname);
		System.assertEquals(2.0, r.pointsScored);
		System.assertEquals(0.667, r.winPercentage);
		
		// Get seasonal results
		results = ResultsController.getSeasonalResults();
		System.assertEquals(3.0, results.pointsAvailable);
		System.assertEquals(2, results.rWrappers.size());
		// Player 1 should be first (3 for 3), player 2 second (2 for 3)
		r = results.rWrappers[0];
		System.assertEquals('Player1', r.nickname);
		System.assertEquals(3.0, r.pointsScored);
		System.assertEquals(1.000, r.winPercentage);
		r = results.rWrappers[1];
		System.assertEquals('Player2', r.nickname);
		System.assertEquals(2.0, r.pointsScored);
		System.assertEquals(0.667, r.winPercentage);
    }
    
    public class Scaffold {
    	Settings__c settings { get; set; }
    	
    	Team__c niners { get; set; }
    	Team__c bears { get; set; }
    	Team__c bengals { get; set; }
    	Team__c bills { get; set; }
    	Team__c broncos { get; set; }
    	Team__c browns { get; set; }
    	Team__c bucs { get; set; }
    	Team__c cards { get; set; }
    	Team__c chargers { get; set; }
    	Team__c chiefs { get; set; }
    	
    	Game__c ninersVsBears { get; set; }
    	Game__c bengalsVsBills { get; set; }
    	Game__c broncosVsBrowns { get; set; }
    	Game__c bucsVsCards { get; set; }
    	Game__c chargersVsChiefs { get; set; }
    	
    	Player__c player1 { get; set; }
    	Player__c player2 { get; set; }
    	Player__c player3 { get; set; }
    	Player__c player4 { get; set; }
    	Player__c player5 { get; set; }
    	
    	public Scaffold() {
    		settings = new Settings__c(Name='PoolManager Settings', NumberOfWeeks__c=4, CurrentWeek__c=1, 
    			MaxGames__c=5, EntryFee__c=50, UsernameSuffix__c='nflpool.com');
    		insert settings;
    		
    		List<Team__c> teamList = new List<Team__c>();
    		niners = new Team__c(Name='San Francisco 49ers', Short_Name__c='49ers');
    		teamList.add(niners);
    		bears = new Team__c(Name='Chicago Bears', Short_Name__c='Bears');
    		teamList.add(bears);
    		bengals = new Team__c(Name='Cinncinnati Bengals', Short_Name__c='Bengals');
    		teamList.add(bengals);
    		bills = new Team__c(Name='Buffalo Bills', Short_Name__c='Bills');
    		teamList.add(bills);
    		broncos = new Team__c(Name='Denver Broncos', Short_Name__c='Broncos');
    		teamList.add(broncos);
    		browns = new Team__c(Name='Cleveland Browns', Short_Name__c='Browns');
    		teamList.add(browns);
    		bucs = new Team__c(Name='Tampa Bay Buccaneers', Short_Name__c='Buccaneers');
    		teamList.add(bucs);
    		cards = new Team__c(Name='St. Louis Cardinals', Short_Name__c='Cardinals');
    		teamList.add(cards);
    		chargers = new Team__c(Name='San Diego Chargers', Short_Name__c='Chargers');
    		teamList.add(chargers);
    		chiefs = new Team__c(Name='Kansas City Chiefs', Short_Name__c='Chiefs');
    		teamList.add(chiefs);
    		insert teamList;
    		
    		// Create five players
    		List<Player__c> playerList = new List<Player__c>();
    		player1 = new Player__c(Name='Player One', Nickname__c='Player1', Settings__c=settings.Id);
    		playerList.add(player1);
    		player2 = new Player__c(Name='Player Two', Nickname__c='Player2', Settings__c=settings.Id);
    		playerList.add(player2);
    		player3 = new Player__c(Name='Player Three', Nickname__c='Player3', Settings__c=settings.Id);
    		playerList.add(player3);
    		player4 = new Player__c(Name='Player Four', Nickname__c='Player4', Settings__c=settings.Id);
    		playerList.add(player4);
    		player5 = new Player__c(Name='Player Five', Nickname__c='Player5', Settings__c=settings.Id);
    		playerList.add(player5);
    		insert playerList;
    		
    	}
    }
}