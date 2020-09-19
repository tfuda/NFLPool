@isTest
private class Test_SelectionController {
	static testMethod void testSelectionController() {
		Settings__c s = UnitTestUtils.createTestSettings();
		UnitTestUtils.createTestTeams();
		UnitTestUtils.createTestGames(s, 16);
		User playerUser = UnitTestUtils.createTestUser();
		User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
		System.runAs(adminUser) {
			// Get a player
			insert playerUser;
			Player__c player = UnitTestUtils.createTestPlayer(playerUser, 'Player');
			PageReference selectionsPage = Page.Selections;
			System.Test.setCurrentPage(selectionsPage);
			SelectionController con = new SelectionController();
			System.assert(con.isadmin);
			System.assertEquals('view', con.mode);
			System.assertEquals(s.currentweek__c, Integer.valueOf(con.weekNumber));
			
			// Simulate selection of a player
			con.selectedPlayer = player.id;
			System.assertEquals(playerUser.CommunityNickname, con.playerName);
			PageReference pgRef = con.go();
			System.assert(pgRef == null);
			System.assertEquals('view', con.mode);
			System.assertEquals(player.Id, con.selectedPlayer);
			con.refreshGameSelections(con.weekNumber, con.selectedPlayer);
			System.assertEquals(16, con.gameSelections.size());
			
			// Simulate editing the selections
			pgRef = con.edit();
			System.assert(pgRef == null);
			System.assertEquals('edit', con.mode);
			
			// Change a game selection and try to save it
			GameSelection gs = con.gameSelections.get(0);
			gs.hSelect = true;
			con.selectedGame = 1;
			pgRef = con.saveSelection();
			System.assertEquals('edit', con.mode);
			gs = con.gameSelections.get(0);
			System.assertEquals(gs.game.home_team__c, gs.selection.team__c);
			pgRef = con.done();
			System.assertEquals('view', con.mode);
			
			System.assert(con.players != null && con.players.size() > 0);
			System.assert(con.weekNumber != null && con.weekNumbers.size() > 0);
			
			// Get a little more coverage
			Boolean test = con.allLocked;
		}
	}
}