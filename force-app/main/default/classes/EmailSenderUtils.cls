public with sharing class EmailSenderUtils {

    // Must exactly match the Display Name of the OrgWideEmailAddress a
    // System Administrator configures in Setup > Organization-Wide Addresses.
    public static final String ORG_WIDE_EMAIL_DISPLAY_NAME = 'NFL Pool Manager';

    public static final String OPT_OUT_FOOTER =
        '\n\n--\n' +
        'You are receiving this email because you are a member of the NFL Pool. ' +
        'If you no longer wish to receive these messages, reply to this email and ' +
        'let a Pool Administrator know.';

    // Messaging.MassEmailMessage cannot carry a custom OrgWideEmailAddress
    // (only SingleEmailMessage supports setOrgWideEmailAddressId), so every
    // send -- single or broadcast -- is built as individual
    // SingleEmailMessages instead. This chunk size keeps each
    // Messaging.sendEmail() call modest; Salesforce also caps the number of
    // sendEmail() invocations per Apex transaction, so a full-roster send
    // stays comfortably within limits at this pool's scale.
    private static final Integer CHUNK_SIZE = 10;

    // Returns null (never throws) if no org-wide address has been created yet,
    // or if it exists but hasn't been verified (the confirmation link Salesforce
    // emails to the address hasn't been clicked). Callers fall back to legacy
    // per-user sender identity in that case rather than failing to send.
    public static OrgWideEmailAddress getVerifiedSender() {
        List<OrgWideEmailAddress> owea = [
            SELECT Id, Address, DisplayName
            FROM OrgWideEmailAddress
            WHERE DisplayName = :ORG_WIDE_EMAIL_DISPLAY_NAME
            AND IsVerified = true
            LIMIT 1
        ];
        return owea.isEmpty() ? null : owea[0];
    }

    public static Boolean wasFallbackUsed(OrgWideEmailAddress configuredSender) {
        return configuredSender == null;
    }

    private static Messaging.SingleEmailMessage buildMessage(
        Id targetId, String subject, String body, Boolean copyMe,
        OrgWideEmailAddress configuredSender, User sendingUser
    ) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(targetId);
        email.setBccSender(copyMe);
        email.setSubject(subject);
        // The From identity stays a single stable address for deliverability
        // (see the branches below), so attribute the actual sender inline in
        // the body instead of varying the From/display name per user.
        email.setPlainTextBody(body + '\n\nSent by ' + sendingUser.Name + '.' + OPT_OUT_FOOTER);
        // setSaveAsActivity(true) is only allowed when the target is a
        // Contact/Lead -- every recipient here is a Salesforce User, so it
        // must stay false or Messaging.sendEmail() rejects every message
        // with "saveAsActivity must be false when sending mail to users."
        email.setSaveAsActivity(false);
        email.setReplyTo(sendingUser.Email);
        // Reply-To always stays the sending admin's real address so replies
        // still reach a human -- only the From identity needs to be stable
        // across sends for reputation purposes.
        if (configuredSender != null) {
            // Salesforce derives the From display name from the
            // OrgWideEmailAddress record's own configured Display Name --
            // calling setSenderDisplayName() at the same time is rejected
            // with "a sender display name may not be specified."
            email.setOrgWideEmailAddressId(configuredSender.Id);
        } else {
            email.setSenderDisplayName(sendingUser.Name + ' (' + sendingUser.CommunityNickname + ')');
        }
        return email;
    }

    // Splits targets into one SingleEmailMessage per recipient, chunked to
    // CHUNK_SIZE per Messaging.sendEmail() call. Pure/no side effects, so
    // tests can exercise this real chunking/message-building logic without
    // needing to actually send anything.
    public static List<List<Messaging.SingleEmailMessage>> buildChunks(
        List<Id> targetIds, String subject, String body, Boolean copyMe,
        OrgWideEmailAddress configuredSender, User sendingUser
    ) {
        List<List<Messaging.SingleEmailMessage>> chunks = new List<List<Messaging.SingleEmailMessage>>();
        List<Messaging.SingleEmailMessage> chunk = new List<Messaging.SingleEmailMessage>();
        for (Id targetId : targetIds) {
            chunk.add(buildMessage(targetId, subject, body, copyMe, configuredSender, sendingUser));
            if (chunk.size() == CHUNK_SIZE) {
                chunks.add(chunk);
                chunk = new List<Messaging.SingleEmailMessage>();
            }
        }
        if (!chunk.isEmpty()) {
            chunks.add(chunk);
        }
        return chunks;
    }

    // Sends one message per target (chunked), so every recipient gets the
    // same From identity -- unlike MassEmailMessage, which can't carry a
    // custom org-wide address at all. Never actually invokes
    // Messaging.sendEmail() in test context, matching this project's
    // established "don't actually send during tests" convention -- but the
    // chunk-building above still runs so that logic stays covered by tests.
    public static List<Messaging.SendEmailResult> sendToTargets(
        List<Id> targetIds, String subject, String body, Boolean copyMe,
        OrgWideEmailAddress configuredSender, User sendingUser
    ) {
        List<List<Messaging.SingleEmailMessage>> chunks = buildChunks(targetIds, subject, body, copyMe, configuredSender, sendingUser);
        List<Messaging.SendEmailResult> allResults = new List<Messaging.SendEmailResult>();
        if (System.Test.isRunningTest()) {
            return allResults;
        }
        for (List<Messaging.SingleEmailMessage> chunk : chunks) {
            allResults.addAll(Messaging.sendEmail(chunk, false));
        }
        return allResults;
    }

    public static List<String> collectErrors(List<Messaging.SendEmailResult> results) {
        List<String> errors = new List<String>();
        for (Messaging.SendEmailResult result : results) {
            if (!result.isSuccess()) {
                for (Messaging.SendEmailError err : result.getErrors()) {
                    errors.add(err.getMessage());
                }
            }
        }
        return errors;
    }

    // Returns null when there's nothing to warn about, otherwise a combined
    // message covering a missing sender address and/or partial send failures.
    public static String buildWarning(Boolean usedFallback, List<Messaging.SendEmailResult> results) {
        List<String> parts = new List<String>();
        if (usedFallback) {
            parts.add('No verified sender address is configured for the pool -- ask your System Administrator to configure one in Setup.');
        }
        List<String> errors = collectErrors(results);
        if (!errors.isEmpty()) {
            parts.add(errors.size() + ' of ' + results.size() + ' recipients could not be reached: ' + String.join(errors, '; '));
        }
        return parts.isEmpty() ? null : String.join(parts, ' ');
    }

    public static Boolean isTotalFailure(List<Messaging.SendEmailResult> results) {
        if (results == null || results.isEmpty()) {
            return false;
        }
        for (Messaging.SendEmailResult result : results) {
            if (result.isSuccess()) {
                return false;
            }
        }
        return true;
    }
}
