@isTest
private class Test_EmailSenderUtils {

    private static User getRunningUser() {
        return [SELECT Id, Name, Email, CommunityNickname FROM User WHERE Id = :UserInfo.getUserId()];
    }

    static testMethod void testGetVerifiedSenderMatchesFallbackLogic() {
        // Whether a verified OrgWideEmailAddress exists depends on whether a
        // System Administrator has completed the manual Setup step in this
        // org -- don't hardcode either state. Just confirm wasFallbackUsed()
        // agrees with whatever getVerifiedSender() actually returns.
        Test.startTest();
        OrgWideEmailAddress sender = EmailSenderUtils.getVerifiedSender();
        Test.stopTest();

        System.assertEquals(sender == null, EmailSenderUtils.wasFallbackUsed(sender));
    }

    static testMethod void testBuildChunksSingleChunkUnderLimit() {
        List<Id> targetIds = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        List<List<Messaging.SingleEmailMessage>> chunks = EmailSenderUtils.buildChunks(
            targetIds, 'Subject', 'Body', null, getRunningUser()
        );
        Test.stopTest();

        System.assertEquals(1, chunks.size());
        System.assertEquals(1, chunks[0].size());
    }

    static testMethod void testBuildChunksSplitsAcrossMultipleChunks() {
        Id me = UserInfo.getUserId();
        List<Id> targetIds = new List<Id>();
        for (Integer i = 0; i < 15; i++) {
            targetIds.add(me);
        }

        Test.startTest();
        List<List<Messaging.SingleEmailMessage>> chunks = EmailSenderUtils.buildChunks(
            targetIds, 'Subject', 'Body', null, getRunningUser()
        );
        Test.stopTest();

        System.assertEquals(2, chunks.size(), '15 targets at a chunk size of 10 should produce 2 chunks');
        System.assertEquals(10, chunks[0].size());
        System.assertEquals(5, chunks[1].size());
    }

    static testMethod void testBuildWarningNoIssues() {
        String warning = EmailSenderUtils.buildWarning(false, new List<Messaging.SendEmailResult>());
        System.assertEquals(null, warning);
    }

    static testMethod void testBuildWarningFallbackOnly() {
        String warning = EmailSenderUtils.buildWarning(true, new List<Messaging.SendEmailResult>());
        System.assertNotEquals(null, warning);
        System.assert(warning.contains('sender address'));
    }

    static testMethod void testIsTotalFailureEmptyResults() {
        System.assertEquals(false, EmailSenderUtils.isTotalFailure(new List<Messaging.SendEmailResult>()));
        System.assertEquals(false, EmailSenderUtils.isTotalFailure(null));
    }

    static testMethod void testCollectErrorsEmptyResults() {
        List<String> errors = EmailSenderUtils.collectErrors(new List<Messaging.SendEmailResult>());
        System.assertEquals(0, errors.size());
    }

    static testMethod void testSendToTargetsSkipsActualSendInTestContext() {
        List<Id> targetIds = new List<Id>{ UserInfo.getUserId() };

        Test.startTest();
        List<Messaging.SendEmailResult> results = EmailSenderUtils.sendToTargets(
            targetIds, 'Subject', 'Body', false, null, getRunningUser()
        );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'No real send should happen during a test');
    }

    static testMethod void testSendToTargetsBuildsConfirmationCopyWhenCopyMeTrue() {
        List<Id> targetIds = new List<Id>{ UserInfo.getUserId() };

        // The confirmation copy is built (exercising buildConfirmationCopy)
        // even though the actual send is skipped in test context -- same
        // "skip the real Messaging.sendEmail(), keep the pure logic covered"
        // pattern as buildChunks/buildMessage.
        Test.startTest();
        List<Messaging.SendEmailResult> results = EmailSenderUtils.sendToTargets(
            targetIds, 'Subject', 'Body', true, null, getRunningUser()
        );
        Test.stopTest();

        System.assertEquals(0, results.size(), 'No real send should happen during a test');
    }
}
