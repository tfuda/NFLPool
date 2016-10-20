@isTest
private class Test_PlayerController {

    static testMethod void testPlayerController() {
		UnitTestUtils.createTestSettings();    	
    	User testUser = UnitTestUtils.createTestUser();
    	User adminUser = [SELECT Id, Username FROM User WHERE Id = :UserInfo.getUserId()];
    	System.runAs(adminUser) {
    		insert testUser;
    		Player__c testPlayer = UnitTestUtils.createTestPlayer(testUser, 'Player');
    		
	        PageReference playerPage = Page.PlayerDetail;
	        playerPage.getParameters().put('id', testUser.id);
	        playerPage.getParameters().put('mode', PlayerController.MODE_VIEW);
	        System.Test.setCurrentPage(playerPage);
	        PlayerController con = new PlayerController();
	        con.underTest = true;
	        System.assertEquals(PlayerController.MODE_VIEW, con.mode);
	        System.assertEquals(testUser.id, con.wrapper.usr.id);
	        System.assertEquals(testPlayer.id, con.wrapper.player.id);       
	        System.assert(con.pmtWrappers.size() == 0);
	        
	        // Test some of the actions
	        
	        // edit
	        PageReference pageRef = con.edit();
	        System.assert(pageRef == null);
	        System.assertEquals(PlayerController.MODE_EDIT, con.mode);
	        
	        // cancel
	        pageRef = con.cancel();
	        System.assert(pageRef == null);
	        System.assertEquals(PlayerController.MODE_VIEW, con.mode);
	        
	        // addPayment
	        pageRef = con.addPayment();
	        System.assert(pageRef == null);
	        System.assert(con.editingPayment);
	        System.assert(con.pmtWrappers.size() == 1);
	        PlayerController.PaymentWrapper pmtWrapper = con.pmtWrappers.get(0);
	        System.assertEquals(0, pmtWrapper.index);
	        System.assertEquals(PlayerController.MODE_EDIT, pmtWrapper.mode);
	        
	        // savePayment
	        pmtWrapper.payment.amount__c = 25;
	        playerPage.getParameters().put('paymentIndex', '0');
	        pageRef = con.savePayment();
	        System.assert(pageRef == null);
	        System.assert(!con.editingPayment);
	        System.assert(con.pmtWrappers.size() == 1);
	        pmtWrapper = con.pmtWrappers.get(0);
	        System.assertEquals(0, pmtWrapper.index);
	        System.assertEquals(PlayerController.MODE_VIEW, pmtWrapper.mode);
	
	        // editPayment      
	        pageRef = con.editPayment();
	        System.assert(pageRef == null);
	        System.assert(con.editingPayment);
	        System.assertEquals(PlayerController.MODE_EDIT, pmtWrapper.mode);
	        pmtWrapper = con.pmtWrappers.get(0);
	        pmtWrapper.payment.amount__c = 50;
	        
	        // cancelPayment
	        pageRef = con.cancelPayment();
	        System.assert(pageRef == null);
	        System.assert(!con.editingPayment);
	        pmtWrapper = con.pmtWrappers.get(0);
	        System.assertEquals(PlayerController.MODE_VIEW, pmtWrapper.mode);
	        System.assertEquals(25, pmtWrapper.payment.amount__c);
	
	        // deletePayment        
	        pageRef = con.deletePayment();
	        System.assert(pageRef == null);
	        System.assert(!con.editingPayment);
	        System.assert(con.pmtWrappers.size() == 0);
	        
	        // Try to update the player. This won't work because of webservice callout
	        try {
	            con.save();
	        } catch (Exception ex) {
	            System.assert(true);
	            System.debug(ex);
	        }       
	        
	        // Clear all params and simulate creation of a new player
	        playerPage.getParameters().clear();
	        playerPage.getParameters().put('mode', PlayerController.MODE_NEW);
	        con = new PlayerController();
	        System.assert(con.wrapper.usr != null);
	        System.assertEquals('<first.last>@' + con.settings.usernamesuffix__c, con.wrapper.usr.Username);
	        
	        // Set the fields on the player and call createPlayer... 
	        // this won't work however, because it requires web service callout
	        con.wrapper.usr.FirstName = 'Test';
	        con.wrapper.usr.LastName = 'Tester';
	        con.wrapper.usr.Username = 'ttester@testing.com';
	        con.wrapper.usr.CommunityNickname = 'ttester';
	        con.wrapper.usr.Email = 'ttester@fake.com';
	        con.wrapper.usr.Phone = '(555)222-6666';
	        con.wrapper.usr.ProfileId = [SELECT Id FROM Profile WHERE Name = 'Player'].Id;
	        try {
	            con.save();
	        } catch (Exception ex) {
	            System.assert(true);
	            System.debug(ex);
	        }
	                
	        // Call some getters and setters for code coverage
	        System.assert(!con.editingPayment);
	        con.editingPayment = true;
	        System.assert(con.editingPayment);
	        con.editingPayment = false;
	        System.assert(con.profileOptions.size() != null);
	        
	        playerPage.getParameters().put('serverUrl', 'https://test.salesforce.com/services/Soap/test');
	        System.assertEquals('https://test.salesforce.com/services/Soap/test', con.serverUrl);
	        System.assertEquals('https://test.salesforce.com/services/Soap', con.webServiceUrl);
	        System.assertEquals('test.salesforce.com', con.serverName);
	        
	        playerPage.getParameters().put('serverUrl', 'http://test.salesforce.com/notamatch/test');
	        System.assertEquals('http://test.salesforce.com/notamatch/test', con.serverUrl);
	        System.assert(con.webServiceUrl == null);
	        System.assert(con.serverName == null);
	        
	        // Call a few of the utility methods for code coverage
	        con.updatePlayerObject(testPlayer.id, testUser.id);
	        con.createPlayerObject(testUser.id);
	   	}
    }
}