public with sharing class EmailService {

    public class Recipient {
        @AuraEnabled public Id userId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String profileName { get; set; }

        public Recipient(User usr) {
            this.userId = usr.Id;
            this.name = usr.Name;
            this.profileName = usr.Profile.Name;
            if (Constants.PLAYER_PROFILE.equals(usr.Profile.Name) ||
                Constants.PLAYER_PLATFORM_PROFILE.equals(usr.Profile.Name)) {
                this.label = usr.Name + ' (' + usr.CommunityNickname + ')';
            } else if (Constants.POOL_ADMIN_PROFILE.equals(usr.Profile.Name)) {
                this.label = usr.Name + ' (' + usr.CommunityNickname + ') *';
            } else if (Constants.SYSTEM_ADMIN_PROFILE.equals(usr.Profile.Name)) {
                this.label = usr.Name + ' *';
            }
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Recipient> getRecipients() {
        List<User> users = [
            SELECT Id, Name, CommunityNickname, Username, Email, Profile.Name
            FROM User
            WHERE IsActive = true
            AND (Profile.Name = :Constants.PLAYER_PROFILE
                OR Profile.Name = :Constants.PLAYER_PLATFORM_PROFILE
                OR Profile.Name = :Constants.POOL_ADMIN_PROFILE
                OR Profile.Name = :Constants.SYSTEM_ADMIN_PROFILE)
            ORDER BY Name ASC
        ];
        List<Recipient> recipients = new List<Recipient>();
        for (User usr : users) {
            recipients.add(new Recipient(usr));
        }
        return recipients;
    }

    @AuraEnabled(cacheable=true)
    public static List<Recipient> getAdminRecipients() {
        List<User> admins = [
            SELECT Id, Name, CommunityNickname, Email, Profile.Name
            FROM User
            WHERE IsActive = true
            AND (Profile.Name = :Constants.POOL_ADMIN_PROFILE
                OR Profile.Name = :Constants.SYSTEM_ADMIN_PROFILE)
            ORDER BY Name ASC
        ];
        List<Recipient> recipients = new List<Recipient>();
        for (User usr : admins) {
            recipients.add(new Recipient(usr));
        }
        return recipients;
    }

    // AuraHandledException.getMessage() only returns the constructor argument
    // if setMessage() is also called explicitly; otherwise callers see a
    // generic "Script-thrown exception" instead of this message.
    private static AuraHandledException newAuraHandledException(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    public class SendEmailOutcome {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String warning { get; set; }
    }

    @AuraEnabled
    public static SendEmailOutcome sendEmail(String subject, String body, List<Id> recipientIds, Boolean copyMe) {
        if (String.isBlank(subject)) {
            throw newAuraHandledException('You must specify a subject for your email.');
        }
        if (String.isBlank(body)) {
            throw newAuraHandledException('You must specify a message for your email.');
        }
        if (recipientIds == null || recipientIds.isEmpty()) {
            throw newAuraHandledException('You must specify at least one recipient for your email.');
        }

        User me = [SELECT Id, Name, Email, CommunityNickname FROM User WHERE Id = :UserInfo.getUserId()];
        OrgWideEmailAddress sender = EmailSenderUtils.getVerifiedSender();
        List<Messaging.SendEmailResult> results = EmailSenderUtils.sendToTargets(recipientIds, subject, body, copyMe, sender, me);

        if (EmailSenderUtils.isTotalFailure(results)) {
            throw newAuraHandledException(
                'Unable to send your email: ' + String.join(EmailSenderUtils.collectErrors(results), '; ')
            );
        }

        SendEmailOutcome outcome = new SendEmailOutcome();
        outcome.success = true;
        outcome.warning = EmailSenderUtils.buildWarning(EmailSenderUtils.wasFallbackUsed(sender), results);
        return outcome;
    }
}
