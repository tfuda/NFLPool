trigger PaymentTrigger on PlayerPayment__c (
	after delete, after insert, after undelete, after update) {
	/*	
	List<Id> playerIds = new List<Id>();
	if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
		// Build List of Player IDs which we need to update
		for (PlayerPayment__c payment : Trigger.newMap.values()) {
			playerIds.add(payment.Player__c);
		}
		
	// Delete trigger
	} else {
		// Build List of Player IDs which we need to update
		for (PlayerPayment__c payment : Trigger.oldMap.values()) {
			playerIds.add(payment.Player__c);
		}
	}
	
	if (playerIds.size() > 0) {
		
		Settings__c settings = PoolManagerUtils.getSettings();
			
		for (Player__c[] players : [select Id, BalanceDue__c, TotalPayments__c, 
			(Select PlayerPayment__c.Amount__c from Player__c.Payments__r) 
			from Player__c where Id in :playerIds]) {
			
			for (Player__c player : players) {
				
				// Reset to TotalPayments to zero
				player.TotalPayments__c = 0;
				
				// Aggregate the amount of payments made by this player
				for (PlayerPayment__c payment : player.Payments__r) {
					player.TotalPayments__c += payment.Amount__c;
				}
				player.BalanceDue__c = settings.EntryFee__c - player.TotalPayments__c;
			}
			update players;
		}
	}
	*/
}