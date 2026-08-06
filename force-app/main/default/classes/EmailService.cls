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

    @AuraEnabled
    public static void sendEmail(String subject, String body, List<Id> recipientIds, Boolean copyMe) {
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
        String senderName = me.Name + ' (' + me.CommunityNickname + ')';

        if (recipientIds.size() == 1) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTargetObjectId(recipientIds[0]);
            email.setBccSender(copyMe);
            email.setReplyTo(me.Email);
            email.setSenderDisplayName(senderName);
            email.setSubject(subject);
            email.setPlainTextBody(body);
            email.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.Email>{ email });
        } else {
            EmailTemplate template = createEmailTemplate(subject, body);
            Messaging.MassEmailMessage email = new Messaging.MassEmailMessage();
            email.setTargetObjectIds(recipientIds);
            email.setBccSender(copyMe);
            email.setReplyTo(me.Email);
            email.setSenderDisplayName(senderName);
            email.setTemplateId(template.Id);
            email.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.Email>{ email });
        }
    }

    private static EmailTemplate createEmailTemplate(String subject, String body) {
        Datetime now = Datetime.now();
        EmailTemplate template = new EmailTemplate(
            DeveloperName = 'Temp_' + UserInfo.getUserId() + '_' + now.format('yyyyMMddHHmmss'),
            Name = 'Temp-' + UserInfo.getUserId() + '-' + now.format('yyyyMMddHHmmss'),
            Description = 'Temporary template created by ' + UserInfo.getUserName() + ' on ' + now.format(),
            Subject = subject,
            Body = body,
            TemplateType = 'text',
            Encoding = 'ISO-8859-1',
            FolderId = UserInfo.getUserId(),
            IsActive = true
        );
        insert template;
        return template;
    }
}
