public with sharing class LCGamesController {
	@AuraEnabled
	public static Game__c[] getGames(String weekNumber) {
		return [SELECT Id, Name, Start_Time__c, Home_Team__c, Home_Team__r.Name, Home_Score__c,
			Visiting_Team__c, Visiting_Team__r.Name, Visiting_Score__c, Spread__c, Final__c, Winner__c, Points__c
			FROM Game__c
			WHERE Week__c = :weekNumber
			ORDER BY Start_Time__c, Name];
	}
}