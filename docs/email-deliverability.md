# Email Deliverability (Email broadcast page)

How the `Email` Visualforce page (`EmailController.cls`) sends broadcast email, why it's built this way, and the exact steps to reproduce the Setup-side configuration in a new org. Written after diagnosing and fixing two real problems: broadcast emails landing in Gmail spam folders, and 10+ minute delivery delays.

## The problem this solves

Before this fix, every send used Salesforce's default outbound mail: whichever admin happened to be logged in became the effective From address, with no stable identity from one send to the next. That destroys sender reputation and looks like spoofing to spam filters — this was the dominant cause of spam-folder placement. There was no custom domain available (personal Gmail addresses only), which ruled out the strongest fix (SPF/DKIM/DMARC on a domain you control).

## Architecture

### Apex (`EmailSenderUtils.cls`, used by `EmailController.cls` and `EmailService.cls`)

- **No `MassEmailMessage`.** `Messaging.MassEmailMessage` cannot call `setOrgWideEmailAddressId()` at all (a real Apex platform limitation, not a version issue) — only `Messaging.SingleEmailMessage` supports it. So every send, single or broadcast, builds one `SingleEmailMessage` per recipient via `buildChunks()`, batched in groups of 10 (`CHUNK_SIZE`) to stay within Salesforce's per-transaction email-invocation limit. This also eliminated the old design's other problem: it used to create a fresh ad-hoc `EmailTemplate` (`Temp_<userid>_<timestamp>`) on every mass send and never cleaned them up — the new design sets subject/body directly on each message, so no `EmailTemplate` is created at all anymore.
- **Sender identity** (`applySenderIdentity()`): if a verified `OrgWideEmailAddress` exists (see below), every message uses it via `setOrgWideEmailAddressId()`. Salesforce derives the From *display name* from the OWEA record's own configured Display Name — calling `setSenderDisplayName()` at the same time is rejected ("a sender display name may not be specified"), so the display name can't vary per sending admin. If no verified OWEA exists yet, it falls back to the old per-user behavior (`sendingUser.Name (nickname)` as display name) rather than failing the send — this is what lets the code deploy safely before the OWEA is created/verified.
- **Per-admin attribution without varying the From identity**: since the From address must stay constant for deliverability, each message body ends with `Sent by {admin's real name}.` before the opt-out footer, so recipients still know who personally sent it.
- **`setSaveAsActivity(false)`** — always. `setSaveAsActivity(true)` is only valid when the target is a Contact/Lead/Person Account; every recipient here is a Salesforce `User`, and setting it `true` makes every send fail with `"saveAsActivity must be false when sending mail to users."`
- **Reply-To** is always the sending admin's real email, regardless of which identity is used for From — so replies reach a human even though the From address is a shared identity.
- **"Copy Me"** sends one separate, clearly-labeled confirmation email to the sender (`buildConfirmationCopy()`, subject prefixed `[Copy]`, body notes how many recipients it went to) rather than BCC-ing the sender on every individual recipient's message — with one `SingleEmailMessage` per recipient, a plain BCC would have produced one inbox copy *per recipient* instead of one total.
- **Opt-out footer** (`OPT_OUT_FOOTER`) is appended to every message: a simple "reply to opt out" note. Sufficient for a private pool's email volume — full one-click List-Unsubscribe isn't necessary here.
- Never actually calls `Messaging.sendEmail()` during Apex tests (`System.Test.isRunningTest()` check) — matches this project's convention of not sending real email in tests. The message-building logic still runs unconditionally so it stays covered by test assertions on the chunk/message structure itself (there are no getters on `Messaging.SingleEmailMessage`, so tests can only assert on shape/counts, not field values).

### The OrgWideEmailAddress (OWEA)

A `SELECT ... FROM OrgWideEmailAddress WHERE DisplayName = 'NFL Pool Manager' AND IsVerified = true` lookup (`EmailSenderUtils.getVerifiedSender()`). The Display Name **must exactly match** the `ORG_WIDE_EMAIL_DISPLAY_NAME` constant at the top of `EmailSenderUtils.cls` (currently `'NFL Pool Manager'`) — this is admin-chosen text, not tied to anything else in Salesforce; if you ever recreate the OWEA with a different name, update the constant to match (or vice versa).

The OWEA address itself is a personal Gmail address (`poolmanagernfl@gmail.com`) — there's no custom domain for this project. That choice is what makes the Email Relay step below necessary.

### Why a personal Gmail address as OWEA isn't enough by itself

Verifying an OWEA only proves you control that mailbox — it does **not** give Salesforce's own sending infrastructure authority to send as `@gmail.com`. Salesforce can't DKIM-sign as a domain it doesn't control, and `gmail.com`'s SPF record doesn't authorize Salesforce's sending IPs. Every message would fail DMARC alignment, and Gmail is especially aggressive about flagging unauthenticated mail claiming to be `from` a `gmail.com` address sent via third-party infrastructure (it's the classic phishing/spoofing pattern). This was very likely also the cause of the 10+ minute delivery delays — receiving servers often throttle/retry-delay mail that fails authentication rather than rejecting it outright.

**A feature that does NOT fix this**: Setup → Email → Deliverability → "Send through Gmail." That's a *per-user* OAuth connection (each Salesforce user connects their own Gmail account under My Email Settings) built around the Activity email composer. It doesn't fit here because it ties delivery to whichever *Salesforce user* happens to be logged in — which breaks down the moment an admin's Salesforce login isn't a Gmail address, or doesn't match the OWEA's address, and it defeats the point of a single consistent sending identity.

**The fix that actually works**: Salesforce **Email Relay**, which is genuinely org-wide and applies to *all* outbound mail — including `Messaging.sendEmail()` calls from Apex using an `OrgWideEmailAddress` (confirmed via the `X-SFDC-EmailCategory: apiSingleMailViaApex` header on a real test send). It routes outbound mail through Gmail's own SMTP servers, authenticated as the OWEA's Gmail account, so the mail is genuinely sent by Google's infrastructure with real SPF/DKIM alignment.

## Setup steps to reproduce in a new org

### 1. Create and verify the OrgWideEmailAddress

Setup → Email → Organization-Wide Addresses → Add:
- Display Name: must exactly match `EmailSenderUtils.ORG_WIDE_EMAIL_DISPLAY_NAME` (currently `NFL Pool Manager`)
- Email Address: the Gmail address to send from
- Allowed Profiles: System Administrator + Pool Administrator
- Save, then open that Gmail inbox and click the verification link Salesforce emails to it. The code stays in the safe per-user fallback (with a page warning) until this is done.

  If the org is SSO/CLI-authenticated only (no known username/password for standard login), the verification link redirects to a standard Salesforce login form that needs real credentials — generate them with `sf org generate password -o <alias>`.

### 2. Generate a Gmail App Password

Gmail's SMTP server (`smtp.gmail.com`) requires authenticated SMTP, which needs an App Password (not the regular account password):
1. Confirm 2-Step Verification is on for the Gmail account (`myaccount.google.com/security`).
2. Go to `myaccount.google.com/apppasswords`, create one (name it something like "Salesforce Relay").
3. Copy the 16-character password — shown only once.

### 3. Configure the Email Relay

Setup → Email → Email Relays → New Email Relay:
- **Host**: `smtp.gmail.com`
- **Port**: `587` (the field defaults to `25` — must be changed)
- **TLS Setting**: `Required` (defaults to `Preferred`, which silently allows an unencrypted fallback that Gmail rejects — must be changed)
- **Enable SMTP Auth**: checked
- **Auth Type**: `Auth Login` (Gmail also supports `Auth Plain`; Auth Login is the more commonly documented choice — try the other if authentication fails)
- **Username**: the OWEA's full Gmail address
- **Password**: the App Password from step 2

Save, and confirm the relay's status is **Active**.

### 4. Activate the relay with an Email Domain Filter

This is a separate step, easy to miss — the relay record alone does nothing. Go to **Setup → Email → Email Delivery Settings → Email Domain Filters** (a distinct Setup page, not a related-list button on the relay record) → New:
- **Sender Domain**: `gmail.com`
- **Recipient Domain**: `*` (required field, can't be left blank — `*` means "any recipient")
- **Email Relay**: the relay record from step 3

Save. This tells Salesforce: any outbound mail whose From address is on `gmail.com` should route through this relay, regardless of recipient.

### 5. Other manual Setup items

- **Deliverability access**: Setup → Email → Deliverability → Access to Send Email = "All Email."
- **Bounce Management**: Setup → Email → Bounce Management → enable, set an internal notification address.

## Verifying it's actually working

Send a real test email, then in Gmail open the received message and use "Show original" (Ctrl+Shift+U). Check:
- `Authentication-Results`: should show `dkim=pass header.i=@gmail.com`, `spf=pass ... smtp.mailfrom=<owea address>`, and `dmarc=pass header.from=gmail.com`.
- The `Received:` chain should show Salesforce's MTA connecting to `smtp.gmail.com` (`ESMTPSA` = authenticated), then Google's own servers handling final delivery.
- Message lands in the Inbox, not Spam, and arrives within seconds rather than minutes.

**A more reliable check than waiting for a bounce**: log into the OWEA's Gmail account and check its own **Sent Mail** folder. Since Salesforce authenticates as that account through the relay, a successfully-relayed message will always show up there — regardless of what happens to it afterward. If a test send doesn't appear in Sent Mail at all, the relay isn't actually engaging (check for typos in the Email Relay record, and confirm the Email Domain Filter's "Email Relay" lookup is actually populated), and Salesforce is silently falling back to its own default (unauthenticated) sending path instead — which explains why Apex can report success while the recipient never gets anything (some receiving providers, e.g. Yahoo, silently discard rather than bounce mail from Salesforce's unauthenticated shared relay).

## One-time cleanup (already done, but for reference)

The old pre-fix code left orphaned `Temp_<userid>_<timestamp>` `EmailTemplate` records behind on every mass send, going back years (262 were found and deleted in `sysadmin`, dating to 2019). `EmailTemplateDeleter.cls` (a `Schedulable` that deletes `Temp_%`-named templates older than 1 hour) already existed but was never scheduled; it was run once via anonymous Apex:

```apex
new EmailTemplateDeleter().execute(null);
```

The new code doesn't create any `EmailTemplate` records at all, so this shouldn't recur — but the class is still there if it ever needs to run again.

## Key gotchas, if this ever needs to be redone or debugged

- `Messaging.MassEmailMessage` cannot call `setOrgWideEmailAddressId()` — compile error, not a runtime issue.
- `Messaging.Email` (the common interface) doesn't expose `setOrgWideEmailAddressId` at the interface level — must be called on the concrete `SingleEmailMessage` type.
- `setSaveAsActivity(true)` only works for Contact/Lead/Person Account targets, never `User` targets.
- `setOrgWideEmailAddressId()` and `setSenderDisplayName()` cannot both be set on the same message.
- `EmailTemplate` doesn't support `FOR UPDATE` row locking.
- `String.join(List<Object>, String separator)` — separator is the *second* argument.
- "Send through Gmail" (per-user OAuth) is a different feature from Email Relay (org-wide SMTP) and doesn't fit an `OrgWideEmailAddress`-based Apex send.
- This Setup-side configuration (OWEA, Email Relay, Email Domain Filter) is **not deployable metadata** pushed through this repo's `sf project deploy` — it has to be manually redone in every org (it was set up independently in both `NFLPoolScratch1` and `sysadmin`).
