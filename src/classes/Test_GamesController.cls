@isTest
private class Test_GamesController {

    static testMethod void testGamesController() {
    	UnitTestUtils.createTestSettings();
    	UnitTestUtils.createTestTeams();
    	
    	PageReference gamesPage = Page.Games;
    	gamesPage.getParameters().put('weekNumber', '1');
    	System.Test.setCurrentPage(gamesPage);
    	GamesController con = new GamesController();
    	System.assert(con.gameList.size() == 0);
    	
    	PageReference pageRef = con.edit();
    	System.assert(pageRef == null);
    	System.assertEquals('edit', con.mode);
    	
    	pageRef = con.addGame();
    	System.assert(pageRef == null);
    	System.assert(con.gameCount == 1);
 
 		con.numGamesToAdd = '3';   	
    	pageRef = con.addMultipleGames();
    	System.assert(pageRef == null);
    	System.assert(con.gameCount == 4);
    	
    	con.deleteButtonId = 'blah:0:deleteButton';
    	pageRef = con.deleteGame();
    	pageRef = con.deleteGame();
    	System.assert(pageRef == null);
    	System.assert(con.gameCount == 2);
    	
    	// Create a couple of games to test the validation stuff
    	List<Team__c> teams = [select id, name, short_name__c from team__c order by short_name__c asc];
    	
    	// First, create two valid games
    	List<GamesController.GameWrapper> gameList = con.gameList;
    	for (Integer i=0; i < gameList.size(); i++) {
    		GamesController.GameWrapper wrapper = gameList.get(i);
    		wrapper.game.home_team__c = teams.get(i * 2).id;
    		wrapper.game.visiting_team__c = teams.get((i * 2) + 1).id;
    	}
    	pageRef = con.quickSave();
    	System.assert(pageRef == null);
    	System.assert(!ApexPages.hasMessages(ApexPages.Severity.ERROR));
    	
    	// Ok, null out one of the games
    	con.gameList.get(0).game.home_team__c = null;
    	con.quickSave();
    	System.assert(ApexPages.hasMessages(ApexPages.Severity.ERROR));
    	
    	// Re-use the same team
    	con.gameList.get(0).game.home_team__c = con.gameList.get(0).game.visiting_team__c;
    	con.quickSave();
    	System.assert(ApexPages.hasMessages(ApexPages.Severity.ERROR));
    	
    	con.gameList.get(0).game.home_team__c = teams.get(0).id;
    	con.gameList.get(0).game.home_score__c = 100;
    	con.gameList.get(0).game.spread__c = 100;
    	con.quickSave();
    	System.assert(ApexPages.hasMessages(ApexPages.Severity.ERROR));
    	
    	// Remove one of the games
    	delete con.gameList.get(1).game;
    	con.gameList.remove(1);
    	
    	// Make the remaining game valid
    	con.gameList.get(0).game.home_team__c = teams.get(0).id;
    	con.gameList.get(0).game.home_score__c = 10;
    	con.gameList.get(0).game.visiting_team__c = teams.get(1).id;
    	con.gameList.get(0).game.visiting_score__c = 10;
    	con.gameList.get(0).game.spread__c = 5;
    	con.gameList.get(0).game.final__c = true;
    	con.quickSave();
    	System.assertEquals(teams.get(0).name, con.gameList.get(0).game.winner__c);
    	
    	pageRef = con.save();
    	System.assert(pageRef == null);    	
    	System.assertEquals('view', con.mode);
    	
    	pageRef = con.edit();
    	System.assert(pageRef == null);    	
    	System.assertEquals('edit', con.mode);
    	
    	pageRef = con.cancel();
    	System.assert(pageRef == null);    	
    	System.assertEquals('view', con.mode);
    	
    	System.assert(con.weekNumbers.size() > 0);
    	System.assert(con.numGameOptions.size() > 0);
    	System.assertEquals(33, con.teamList.size());
    }

}