@isTest
private class Test_GameSelection {
    
    static testMethod void testGameSelection() {
    	UnitTestUtils.createTestSettings();
    	UnitTestUtils.createTestTeams();
    	User testUser = UnitTestUtils.createTestUser();
    	User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    	System.runAs(adminUser) {
    		insert testUser;
    		Player__c testPlayer = UnitTestUtils.createTestPlayer(testUser, 'Player');
	    	List<Team__c> teams = [SELECT Id, Name FROM Team__c ORDER BY Name ASC];
	    	Team__c home = teams.get(0);
	    	Team__c visitor = teams.get(1);
	    	Game__c game = new Game__c();
	    	game.week__c = '1';
	    	game.home_team__c = home.id;
	    	game.visiting_team__c = visitor.id;
	    	game.start_time__c = Datetime.now().addMinutes(-1);
	    	insert game;
	    	GameSelection gs = new GameSelection(1, testPlayer.id, game, null); 
			System.assertEquals(game.home_team__c, gs.game.home_team__c);    	
			System.assertEquals(game.visiting_team__c, gs.game.visiting_team__c);
			System.assert(true == gs.isLocked);
			System.assert(false == gs.isDirty);
			gs.hSelect = true;
			System.assert(true == gs.isDirty);
			System.assertEquals(home.id, gs.selectedTeam);
			System.debug('home:' + home);
			System.debug('gs:' + gs);
			System.debug('selectedteam: ' + gs.selectedTeam);
			try {
				gs.save(false);
				System.assert(false);
			} catch (SaveException ex) {
				System.assert(true);
			}
			try {
				gs.save(true);
				System.assert(true);
			} catch (SaveException ex) {
				System.assert(false);
			}
			System.assert(gs.selection != null);
			System.assertEquals(home.id, gs.selection.team__c);
			System.assertEquals(game.id, gs.selection.game__c);
			System.assertEquals(testPlayer.id, gs.selection.player__c); 
			
			gs.hSelect = false;
			gs.vSelect = true;
			gs.save(true);
			System.assertEquals(visitor.id, gs.selection.team__c);	
			System.assert(false == gs.isDirty);	
    	}
    }

    static testMethod void testNewGameSelection() {
    	UnitTestUtils.createTestSettings();
    	UnitTestUtils.createTestTeams();
    	User testUser = UnitTestUtils.createTestUser();
    	User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    	System.runAs(adminUser) {
    		Player__c p = UnitTestUtils.createTestPlayer(testUser, 'Player');
	    	List<Team__c> teams =[SELECT Id, Name FROM Team__c ORDER BY Name ASC];
	    	Team__c home = teams.get(0);
	    	Team__c visitor = teams.get(1);
	    	Game__c game = new Game__c();
	    	game.week__c = '1';
	    	game.home_team__c = home.id;
	    	game.visiting_team__c = visitor.id;
	    	game.start_time__c = Datetime.now().addMinutes(-1);
	    	insert game;
	    	New_GameSelection gs = new New_GameSelection(1, p.id, game, null); 
			System.assertEquals(game.home_team__c, gs.game.home_team__c);    	
			System.assertEquals(game.visiting_team__c, gs.game.visiting_team__c);
			System.assert(true == gs.isLocked);
			System.assert(false == gs.isDirty);
			gs.hSelect = true;
			System.assert(true == gs.isDirty);
			System.assertEquals(home.id, gs.selectedTeam);
			try {
				gs.save(false);
				System.assert(false);
			} catch (SaveException ex) {
				System.assert(true);
			}
			try {
				gs.save(true);
				System.assert(true);
			} catch (SaveException ex) {
				System.assert(false);
			}
			System.assert(gs.selection != null);
			System.assertEquals(home.id, gs.selection.team__c);
			System.assertEquals(game.id, gs.selection.game__c);
			System.assertEquals(p.id, gs.selection.player__c); 
			
			gs.hSelect = false;
			gs.vSelect = true;
			gs.save(true);
			System.assertEquals(visitor.id, gs.selection.team__c);	
			System.assert(false == gs.isDirty);
    	}	
    }
}