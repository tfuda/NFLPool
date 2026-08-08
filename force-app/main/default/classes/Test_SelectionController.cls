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
			PageReference printableSelectionsPage = Page.PrintableSelections;
			System.Test.setCurrentPage(printableSelectionsPage);
			SelectionController con = new SelectionController();
			System.assert(con.isadmin);
			System.assertEquals(s.currentweek__c, Integer.valueOf(con.weekNumber));

			// Simulate selection of a player
			con.selectedPlayer = player.id;
			System.assertEquals(playerUser.CommunityNickname, con.playerName);
			con.refreshGameSelections(con.weekNumber, con.selectedPlayer);
			System.assertEquals(16, con.gameSelections.size());

			GameSelection gs = con.gameSelections.get(0);
			System.assertEquals(1, gs.gameNumber);
		}
	}
}
