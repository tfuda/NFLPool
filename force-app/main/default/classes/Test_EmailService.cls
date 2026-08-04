@isTest
private class Test_EmailService {

    static testMethod void testGetRecipients() {
        Test.startTest();
        List<EmailService.Recipient> recipients = EmailService.getRecipients();
        Test.stopTest();

        // At minimum, the running user (System Administrator) should appear
        System.assert(recipients.size() > 0);
        Boolean foundAdmin = false;
        for (EmailService.Recipient r : recipients) {
            System.assertNotEquals(null, r.userId);
            System.assertNotEquals(null, r.name);
            System.assertNotEquals(null, r.label);
            if (r.profileName == 'System Administrator') {
                foundAdmin = true;
                System.assert(r.label.contains('*'));
            }
        }
        System.assert(foundAdmin, 'Should find at least one System Administrator');
    }

    static testMethod void testGetAdminRecipients() {
        Test.startTest();
        List<EmailService.Recipient> admins = EmailService.getAdminRecipients();
        Test.stopTest();

        System.assert(admins.size() > 0);
        for (EmailService.Recipient r : admins) {
            System.assert(
                r.profileName == 'Pool Administrator' || r.profileName == 'System Administrator',
                'Admin recipients should only include admin profiles'
            );
        }
    }

    static testMethod void testSendEmailValidationNoSubject() {
        Test.startTest();
        try {
            EmailService.sendEmail(null, 'body', new List<Id>{ UserInfo.getUserId() }, false);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('subject'));
        }
        Test.stopTest();
    }

    static testMethod void testSendEmailValidationNoBody() {
        Test.startTest();
        try {
            EmailService.sendEmail('subject', '', new List<Id>{ UserInfo.getUserId() }, false);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('message'));
        }
        Test.stopTest();
    }

    static testMethod void testSendEmailValidationNoRecipients() {
        Test.startTest();
        try {
            EmailService.sendEmail('subject', 'body', new List<Id>(), false);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('recipient'));
        }
        Test.stopTest();
    }

    static testMethod void testSendEmailSingle() {
        Test.startTest();
        EmailService.sendEmail(
            'Test Subject',
            'Test Body',
            new List<Id>{ UserInfo.getUserId() },
            false
        );
        Test.stopTest();

        // If we get here without exception, the single email path worked
        System.assert(true);
    }

    static testMethod void testSendEmailMass() {
        // Need at least 2 recipients for mass email path
        List<Id> recipientIds = new List<Id>();
        List<User> users = [SELECT Id FROM User WHERE IsActive = true AND Profile.Name = 'System Administrator' LIMIT 2];
        for (User u : users) {
            recipientIds.add(u.Id);
        }
        // If only 1 admin, add same user twice — mass email needs 2+ target IDs
        if (recipientIds.size() < 2) {
            recipientIds.add(recipientIds[0]);
        }

        Test.startTest();
        EmailService.sendEmail(
            'Test Mass Subject',
            'Test Mass Body',
            recipientIds,
            true
        );
        Test.stopTest();

        // Verify the temporary email template was created
        List<EmailTemplate> templates = [
            SELECT Id, Subject FROM EmailTemplate
            WHERE DeveloperName LIKE 'Temp_%'
        ];
        System.assert(templates.size() > 0);
    }
}
