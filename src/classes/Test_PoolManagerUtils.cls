@isTest
private class Test_PoolManagerUtils {
	
	static testMethod void testCreateUpdatePlayerUser() {
		Profile p = [select id from profile where name='Standard User' limit 1];
		String userId = PoolManagerUtils.createPlayerUser(
			'First', 'Last', 'first.last@testuser.com', 'flast', 
			'first.last@test.com', '(555)111-2233', 
			'123 Main Street', 'Anytown', 'AL', '12345', 
			p.id, false);
		System.assert(userId != null);
		User u = [select id, firstname, lastname, username, communitynickname, 
			email, phone, street, city, state, postalcode,
			profileid, isactive from User where id = :userId limit 1];
		System.assertEquals('First', u.firstname);					
		System.assertEquals('Last', u.lastname);					
		System.assertEquals('first.last@testuser.com', u.username);					
		System.assertEquals('flast', u.communitynickname);
		System.assertEquals('first.last@test.com', u.email);
		System.assertEquals('(555)111-2233', u.phone);
		System.assertEquals('123 Main Street', u.street);
		System.assertEquals('Anytown', u.city);
		System.assertEquals('AL', u.state);
		System.assertEquals('12345', u.postalcode);
		System.assertEquals(p.id, u.profileid);
		System.assert(!u.isactive);					
							
		userId = PoolManagerUtils.updatePlayerUser(userId, 
			'John', 'Doe', 'first.last@testuser.com', 'jdoe',
			'first.last@test.com', '(555)666-7777', 
			'456 Elm Street', 'Everytown', 'CT', '05654', 
			p.id, false);		
		System.assert(userId != null);
		u = [select id, firstname, lastname, username, communitynickname, 
			email, phone, street, city, state, postalcode,
			profileid, isactive from User where id = :userId limit 1];
		System.assertEquals('John', u.firstname);					
		System.assertEquals('Doe', u.lastname);					
		System.assertEquals('jdoe', u.communitynickname);
		System.assertEquals('(555)666-7777', u.phone);
		System.assertEquals('456 Elm Street', u.street);
		System.assertEquals('Everytown', u.city);
		System.assertEquals('CT', u.state);
		System.assertEquals('05654', u.postalcode);
		System.assertEquals(p.id, u.profileid);
		System.assert(!u.isactive);					
	}
	
	static testMethod void testGetSettings() {
		UnitTestUtils.createTestSettings();
		
		// Assumes settings object exists
		Settings__c s = PoolManagerUtils.getSettings();
		System.assertEquals(1, s.CurrentWeek__c);
		System.assertEquals(150.00, s.EntryFee__c);
		System.assertEquals(16, s.MaxGames__c);
		System.assertEquals(17, s.NumberOfWeeks__c);
		System.assertEquals('nflpool.com', s.UsernameSuffix__c);
	}
}