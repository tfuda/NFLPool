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

    // Common to every outgoing message, including the sender's own
    // confirmation copy: the From identity stays a single stable address for
    // deliverability, so the actual sender is attributed inline in the body
    // instead (see buildMessage/buildConfirmationCopy), not via From/display
    // name, which can't vary per user alongside an OrgWideEmailAddress.
    private static void applySenderIdentity(
        Messaging.SingleEmailMessage email, OrgWideEmailAddress configuredSender, User sendingUser
    ) {
        // setSaveAsActivity(true) is only allowed when the target is a
        // Contact/Lead -- every recipient here is a Salesforce User, so it
        // must stay false or Messaging.sendEmail() rejects every message
        // with "saveAsActivity must be false when sending mail to users."
        email.setSaveAsActivity(false);
        // Reply-To always stays the sending admin's real address so replies
        // still reach a human -- only the From identity needs to be stable
        // across sends for reputation purposes.
        email.setReplyTo(sendingUser.Email);
        if (configuredSender != null) {
            // Salesforce derives the From display name from the
            // OrgWideEmailAddress record's own configured Display Name --
            // calling setSenderDisplayName() at the same time is rejected
            // with "a sender display name may not be specified."
            email.setOrgWideEmailAddressId(configuredSender.Id);
        } else {
            email.setSenderDisplayName(sendingUser.Name + ' (' + sendingUser.CommunityNickname + ')');
        }
    }

    private static Messaging.SingleEmailMessage buildMessage(
        Id targetId, String subject, String body,
        OrgWideEmailAddress configuredSender, User sendingUser
    ) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(targetId);
        email.setSubject(subject);
        email.setPlainTextBody(body + '\n\nSent by ' + sendingUser.Name + '.' + OPT_OUT_FOOTER);
        applySenderIdentity(email, configuredSender, sendingUser);
        return email;
    }

    // A separate, clearly-labeled email to the sender rather than a BCC on
    // each recipient's message -- BCC-ing every individual SingleEmailMessage
    // in the batch would land one copy per recipient in the sender's inbox
    // instead of the single copy "Copy Me" is meant to produce.
    private static Messaging.SingleEmailMessage buildConfirmationCopy(
        String subject, String body, Integer recipientCount,
        OrgWideEmailAddress configuredSender, User sendingUser
    ) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(sendingUser.Id);
        email.setSubject('[Copy] ' + subject);
        email.setPlainTextBody(
            'This is a copy of the message you just sent to ' + recipientCount +
                (recipientCount == 1 ? ' recipient' : ' recipients') + '.\n\n---\n\n' +
                body + OPT_OUT_FOOTER
        );
        applySenderIdentity(email, configuredSender, sendingUser);
        return email;
    }

    // Splits targets into one SingleEmailMessage per recipient, chunked to
    // CHUNK_SIZE per Messaging.sendEmail() call. Pure/no side effects, so
    // tests can exercise this real chunking/message-building logic without
    // needing to actually send anything.
    public static List<List<Messaging.SingleEmailMessage>> buildChunks(
        List<Id> targetIds, String subject, String body,
        OrgWideEmailAddress configuredSender, User sendingUser
    ) {
        List<List<Messaging.SingleEmailMessage>> chunks = new List<List<Messaging.SingleEmailMessage>>();
        List<Messaging.SingleEmailMessage> chunk = new List<Messaging.SingleEmailMessage>();
        for (Id targetId : targetIds) {
            chunk.add(buildMessage(targetId, subject, body, configuredSender, sendingUser));
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
    // The optional confirmation copy (when copyMe is true) is sent separately
    // and its result isn't mixed into the returned list, so buildWarning()'s
    // "N of M recipients" accounting only ever reflects real recipients.
    public static List<Messaging.SendEmailResult> sendToTargets(
        List<Id> targetIds, String subject, String body, Boolean copyMe,
        OrgWideEmailAddress configuredSender, User sendingUser
    ) {
        List<List<Messaging.SingleEmailMessage>> chunks = buildChunks(targetIds, subject, body, configuredSender, sendingUser);
        Messaging.SingleEmailMessage confirmationCopy = copyMe
            ? buildConfirmationCopy(subject, body, targetIds.size(), configuredSender, sendingUser)
            : null;

        List<Messaging.SendEmailResult> allResults = new List<Messaging.SendEmailResult>();
        if (System.Test.isRunningTest()) {
            return allResults;
        }
        for (List<Messaging.SingleEmailMessage> chunk : chunks) {
            allResults.addAll(Messaging.sendEmail(chunk, false));
        }
        if (confirmationCopy != null) {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ confirmationCopy }, false);
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
