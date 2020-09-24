@isTest
private class Test_PlayerWrapper {
	
	static testMethod void testPlayerWrapper() {
		UnitTestUtils.createTestSettings();
		User testUser = UnitTestUtils.createTestUser();
		User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
		System.runAs(adminUser) {
			insert testUser;
			Player__c testPlayer = UnitTestUtils.createTestPlayer(testUser, 'Player');
			
			// Create a test payment    	
			PlayerPayment__c testPayment = new PlayerPayment__c();
			testPayment.amount__c = 100;
			testPayment.player__c = testPlayer.id;
			insert testPayment;
			
			PlayerWrapper wrapper = PlayerWrapper.getPlayerWrapper(testUser.id);
			System.assertEquals(testUser.id, wrapper.usr.id);
			System.assertEquals(testPlayer.id, wrapper.player.id);
			System.assert(wrapper.player.TotalPaymentsRollup__c == 100);
			System.assert(wrapper.player.BalanceDueFormula__c == 50);
			
			List<User> users = [select id from user where profile.name = 'Player'];
			List<Id> userIds = new List<Id>();
			for (User u : users) {
				userIds.add(u.id);
			}
			List<PlayerWrapper> playerWrapperList = PlayerWrapper.getPlayerWrapperList(userIds);
			System.assert(playerWrapperList.size() > 0);
		}
	}
}