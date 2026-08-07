@isTest
private class Test_EmailController {
	static testMethod void testEmailController() {
		PageReference emailLandingPage = Page.EmailLanding;
		System.Test.setCurrentPage(emailLandingPage);
		EmailController con = new EmailController();
		con.underTest = true;
		
		PageReference pageRef = con.emailPlayers();
		System.assert(pageRef.getUrl().startsWith(Page.Email.getUrl()));
		System.assertEquals('emailPlayers', con.mode);
		System.assert(con.playerList != null && con.playerList.size() > 0);
		con.subject = 'Test Subject';
		con.message = 'Test Message';
		con.copyMe = true;
		con.selectAll = true;
		con.selectDeselectAll();
		pageRef = con.send();
		System.assert(pageRef.getUrl().startsWith(Page.Email.getUrl()));
		System.assert(ApexPages.hasMessages(ApexPages.Severity.INFO));
		ApexPages.getMessages().clear();
		
		// Now email admins
		pageRef = con.emailAdmins();
		System.assert(pageRef.getUrl().startsWith(Page.Email.getUrl()));
		System.assertEquals('emailAdmins', con.mode);
		con.subject = 'Test Subject';
		con.message = 'Test Message';
		con.copyMe = false;
		pageRef = con.send();
		System.assert(pageRef.getUrl().startsWith(Page.Email.getUrl()));
		System.assert(ApexPages.hasMessages(ApexPages.Severity.INFO));
		ApexPages.getMessages().clear();
		
		// Send with no recipients selected
		con.emailPlayers();
		con.selectAll = false;
		con.selectDeselectAll();
		pageRef = con.send();
		System.assert(pageRef.getUrl().startsWith(Page.Email.getUrl()));
		System.assert(ApexPages.hasMessages(ApexPages.Severity.ERROR));
		ApexPages.getMessages().clear();
		
		// No subject or message
		con.subject = null;
		con.message = null;
		pageRef = con.send();
		System.assert(pageRef.getUrl().startsWith(Page.Email.getUrl()));
		System.assert(ApexPages.hasMessages());
		ApexPages.getMessages().clear();
		
		pageRef = con.cancel();
		System.assert(pageRef.getUrl().startsWith(Page.Email.getUrl()));

	}

	// Broadcast sends now build one SingleEmailMessage per recipient instead
	// of a MassEmailMessage backed by an ad-hoc EmailTemplate (the old
	// implementation left an orphaned Temp_* template behind on every send).
	// Verify no EmailTemplate records get created at all anymore.
	static testMethod void testMassEmailCreatesNoOrphanedTemplates() {
		Integer templateCountBefore = [SELECT COUNT() FROM EmailTemplate];

		PageReference emailLandingPage = Page.EmailLanding;
		System.Test.setCurrentPage(emailLandingPage);
		EmailController con = new EmailController();
		con.underTest = true;
		con.emailPlayers();
		con.selectAll = true;
		con.selectDeselectAll();
		con.subject = 'Test Subject';
		con.message = 'Test Message';
		con.send();

		Integer templateCountAfter = [SELECT COUNT() FROM EmailTemplate];
		System.assertEquals(templateCountBefore, templateCountAfter, 'Sending should not create any EmailTemplate records');
	}
}