@isTest
private class TriggerTests {
	
	static testMethod void testTriggers() {
		Settings__c settings = UnitTestUtils.createTestSettings();
		User testUser = UnitTestUtils.createTestUser();
		User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
		System.runAs(adminUser) {
			insert testUser;
			Player__c newPlayer = UnitTestUtils.createTestPlayer(testUser, 'Player');
			Player__c updatedPlayer = [select Id, BalanceDueFormula__c, TotalPaymentsRollup__c from Player__c where Name = 'Test Player' limit 1];
			System.assert(updatedPlayer.TotalPaymentsRollup__c == 0);
			System.assert(updatedPlayer.BalanceDueFormula__c == settings.EntryFee__c);
			
			// Create a payment
			PlayerPayment__c payment1 = new PlayerPayment__c(Amount__c = 25, Player__c = updatedPlayer.Id);
			insert payment1;
			
			updatedPlayer = [select Id, BalanceDueFormula__c, TotalPaymentsRollup__c from Player__c where Name = 'Test Player' limit 1];
			System.assert(updatedPlayer.TotalPaymentsRollup__c == payment1.Amount__c);
			System.assert(updatedPlayer.BalanceDueFormula__c == (settings.EntryFee__c - updatedPlayer.TotalPaymentsRollup__c));
			
			PlayerPayment__c payment2 = new PlayerPayment__c(Amount__c = 25, Player__c = updatedPlayer.Id);
			insert payment2;
			
			updatedPlayer = [select Id, BalanceDueFormula__c, TotalPaymentsRollup__c from Player__c where Name = 'Test Player' limit 1];
			System.assert(updatedPlayer.TotalPaymentsRollup__c == (payment1.Amount__c + payment2.Amount__c));
			System.assert(updatedPlayer.BalanceDueFormula__c == (settings.EntryFee__c - updatedPlayer.TotalPaymentsRollup__c));
			
			payment2.Amount__c = 50;
			update payment2;
			
			updatedPlayer = [select Id, BalanceDueFormula__c, TotalPaymentsRollup__c from Player__c where Name = 'Test Player' limit 1];
			System.assert(updatedPlayer.TotalPaymentsRollup__c == (payment1.Amount__c + payment2.Amount__c));
			System.assert(updatedPlayer.BalanceDueFormula__c == (settings.EntryFee__c - updatedPlayer.TotalPaymentsRollup__c));
			
			delete payment2;
			updatedPlayer = [select Id, BalanceDueFormula__c, TotalPaymentsRollup__c from Player__c where Name = 'Test Player' limit 1];
			System.assert(updatedPlayer.TotalPaymentsRollup__c == payment1.Amount__c);
			System.assert(updatedPlayer.BalanceDueFormula__c == (settings.EntryFee__c - updatedPlayer.TotalPaymentsRollup__c));
		}
	}
}