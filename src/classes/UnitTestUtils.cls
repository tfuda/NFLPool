@IsTest
public with sharing class UnitTestUtils {
	
	public static Settings__c createTestSettings() {
		Settings__c s = new Settings__c(
			Name = 'Pool Settings',
			CurrentWeek__c = 1,
			EntryFee__c = 150.00,
			MaxGames__c = 16,
			NumberOfWeeks__c = 17,
			UsernameSuffix__c = 'nflpool.com'
		);
		insert s;
		return s;
	}
	
	public static User createTestUser() {
		Profile p = [select id from profile where name='Player'];
		User u = new User(
			Alias = 'tplayer', 
			EmailEncodingKey = 'UTF-8',
			FirstName = 'Test', 
			LastName = 'Player',
			Email = 'tuser@test.com',
			Phone = '(222) 333-4444',
			Street = '123 Main Street', 
			City = 'Stamford', 
			State = 'CT', 
			PostalCode = '06905',
			LanguageLocaleKey='en_US', 
			LocaleSidKey = 'en_US', 
			ProfileId = p.Id,
			TimeZoneSidKey = 'America/New_York', 
			Username='test.player@nflpool.com',
			CommunityNickname='tplayer123'
		);
		return u;
	}
	
	public static Player__c createTestPlayer(User u, String nickname) {
		Player__c p = new Player__c(
			Name = u.FirstName + ' ' + u.LastName,
			Nickname__c = nickname,
			Phone__c = u.Phone,
			Settings__c = [SELECT Id FROM Settings__c].Id,
			User__c = u.Id
		);
		insert p;
		return p;
	}
	
	public static List<Team__c> createTestTeams() {
		List<Team__c> teamList = (List<Team__c>) System.Test.loadData(Team__c.SObjectType, 'testTeams');
		return teamList;
	}
	
	// Creates the specified number of games for the current week. Games are generated in order by team list
	public static List<Game__c> createTestGames(Settings__c settings, Integer numGames) {
		List<Team__c> teamList = [SELECT Id, Name, Short_Name__c FROM Team__c ORDER BY Short_Name__c];
		List<Game__c> gameList = new List<Game__c>();
		for (Integer i = 0; i < numGames; i++) {
			Game__c game = new Game__c(
				Week__c = String.valueOf(settings.CurrentWeek__c),
				Home_Team__c = teamList[i].Id,
				Visiting_Team__c = teamList[i+1].Id,
				Final__c = false,
				Start_Time__c = DateTime.now().addDays(1),
				Spread__c = Double.valueOf(i)
			);
			gameList.add(game);
		}
		insert gameList;
		return gameList;
	}
}