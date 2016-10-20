@isTest
private class Test_ContactInfoController {
    static testMethod void testContactInfoController() {
    	UnitTestUtils.createTestSettings();
        PageReference contactInfo = Page.ContactInfo;
        System.Test.setCurrentPage(contactInfo);
        ContactInfoController con = new ContactInfoController();
        List<PlayerWrapper> adminList = con.getPoolAdmins();
        System.assert(adminList != null);
    }
}