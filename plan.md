# NFLPool Modernization Plan: Visualforce to Lightning Web Components

## Goal
Migrate the NFLPool app from Visualforce pages to Lightning Web Components (LWC) with the Salesforce Lightning Design System (SLDS), producing a responsive UI that works on desktop browsers, mobile browsers, and the Salesforce Mobile App.

---

## Architecture Overview

### Current State
- 14 Visualforce pages, 8 Apex controllers
- jQuery/jQuery UI for dialogs and interactivity
- SOAP `webService` methods for user provisioning
- All controller methods tightly coupled to `ApexPages.*` APIs
- No `@AuraEnabled` methods exist

### Target State
```
LWC Components (UI)
    ↕ @wire / imperative calls
Apex Service Layer (@AuraEnabled methods)
    ↕
Existing Data Model + Triggers (unchanged)
```

**Key principles:**
- Triggers and custom objects remain unchanged
- Extract business logic from VF controllers into a new `@AuraEnabled` service layer
- Each VF page becomes one or more LWC components
- Use SLDS for all styling (responsive out of the box)
- Use Lightning Navigation Service for page transitions
- Use `lightning-record-*` base components where possible to reduce custom code

---

## Phase 0: Foundation (Do First)

### 0.1 — Create the Apex Service Layer
Extract business logic out of VF controllers into clean, testable service classes with `@AuraEnabled` methods. This is the prerequisite for all LWC work.

**New classes to create:**

| Class | Source Logic | Key `@AuraEnabled` Methods |
|-------|-------------|---------------------------|
| `GameService` | `GamesController` | `getGamesForWeek`, `saveGames`, `deleteGame`, `getWeekNumbers` |
| `SelectionService` | `SelectionController`, `GameSelection` | `getSelectionsForPlayerWeek`, `saveSelection`, `getPlayers` |
| `ResultsService` | `ResultsController` | `getWeeklyResults`, `getSeasonalResults` |
| `PlayerService` | `PlayerController`, `PoolManagerUtils` | `getPlayer`, `savePlayer`, `createPlayerUser`, `updatePlayerUser`, `getPayments`, `savePayment`, `deletePayment` |
| `EmailService` | `EmailController` | `getRecipients`, `sendEmail` |
| `SettingsService` | `PoolManagerUtils` | `getSettings`, `isCurrentUserAdmin` |

**Critical changes:**
- Convert `PoolManagerUtils.webService` methods → `@AuraEnabled` static methods (SOAP `webService` is legacy and incompatible with LWC)
- Fix N+1 query in `GameWrapper.isLocked` — batch-load lock status
- Cache admin role check (currently queries profile on every page load)
- Replace `ApexPages.Message` error handling with `AuraHandledException`
- `SoapUtils.cls` can be deleted once SOAP calls are replaced

### 0.2 — Update Project Configuration
- Update `sfdx-project.json` API version to latest (v62.0+)
- Add Chart.js as a static resource or npm dependency (currently loaded from CDN, which won't work in LWC)
- Update `package.xml` manifest for new components

---

## Phase 1: Simple Static/Read-Only Pages

Low-risk pages to build LWC confidence and establish patterns.

### 1.1 — `helpfulLinks` (LWC)
_Replaces: HelpfulLinks.page_
- Static list of links using `lightning-card` and `lightning-formatted-url`
- No Apex needed
- **Complexity: Trivial**

### 1.2 — `homePageMessage` (LWC)
_Replaces: HomePageMessage.page_
- Static prize breakdown content in a `lightning-card`
- Consider making it data-driven from `Settings__c` for flexibility
- **Complexity: Trivial**

### 1.3 — `contactInfo` (LWC)
_Replaces: ContactInfo.page → ContactInfoController_
- Calls `SettingsService.getAdminContacts()` via `@wire`
- Displays admin list using `lightning-layout` (responsive grid)
- **Complexity: Simple**

### 1.4 — `chatterMessageBoard` / `adminMessageBoard` (LWC)
_Replaces: ChatterMessageBoard.page, AdminMessageBoard.page_
- Use the standard `lightning/chatterFeed` base component or embed via `forceChatter:feed`
- Pass the Chatter Group ID from `SettingsService`
- **Complexity: Simple** (but verify Chatter LWC component availability)

---

## Phase 2: Read-Write Forms & Lists

### 2.1 — `myAccount` (LWC)
_Replaces: MyAccount.page_
- View/edit form for current user's player record
- Use `lightning-record-edit-form` or `lightning-input` fields
- Read-only `lightning-datatable` for payment history
- Totals displayed with `lightning-formatted-number`
- Responsive with `lightning-layout` rows/columns
- **Complexity: Moderate**

### 2.2 — `playerManagement` (LWC)
_Replaces: PlayerManagement.page → PlayerListController_
- `lightning-datatable` with sortable columns, row actions (activate/deactivate/edit)
- Toggle for "active only" filter as `lightning-input` checkbox
- Search/filter bar using `lightning-input` with `onchange` debounce
- Client-side pagination or server-side via `OFFSET`/`LIMIT`
- "New Player" button navigates to `playerDetail`
- **Complexity: Moderate**

### 2.3 — `playerDetail` (LWC)
_Replaces: PlayerDetail.page → PlayerController_
- Three modes: view / edit / new (managed via component state)
- Player info section: `lightning-record-edit-form` with `lightning-input-field`
- Payment history: `lightning-datatable` with inline-edit capability
- Add/delete payment actions via `lightning-button-icon`
- **Critical:** Replace SOAP `webService` user creation with `@AuraEnabled` call to `PlayerService.createPlayerUser()`
- Profile picker: `lightning-combobox`
- **Complexity: High** (due to user provisioning logic)

### 2.4 — `emailComposer` (LWC)
_Replaces: Email.page + EmailLanding.page → EmailController_
- Combine landing + compose into a single component
- Mode toggle (Players / Admins) via `lightning-button-group` or `lightning-tab`
- Recipient grid: `lightning-checkbox-group` or custom checkbox list with `lightning-layout` grid
- Select All / Deselect All via `lightning-button`
- Subject: `lightning-input`, Message: `lightning-textarea`
- Send action calls `EmailService.sendEmail()`
- Toast notifications for success/error via `lightning/platformShowToastEvent`
- **Complexity: Moderate**

---

## Phase 3: Core Feature Pages (High Complexity)

### 3.1 — `results` (LWC)
_Replaces: Results.page → ResultsController_
- Week navigation: `lightning-button-group` or horizontal `lightning-tabset`
- Results table: `lightning-datatable` with conditional formatting (highlight leaders)
- Charts: Import Chart.js from static resource using `loadScript()` from `lightning/platformResourceLoader`
  - Bar chart for points, bar chart for win percentage
  - Render into a `<canvas>` element inside the LWC template
- Auto-refresh: Use `setInterval` in `connectedCallback()`, clear in `disconnectedCallback()`
- Season-wide standings tab alongside weekly view
- Mobile: Stack chart below table; table scrolls horizontally
- **Complexity: High**

### 3.2 — `games` (LWC)
_Replaces: Games.page → GamesController_
- Week selector: `lightning-combobox` or tab bar
- Game list: Custom card-based layout (each game is a `lightning-card` or SLDS card)
  - View mode: team names, spread, scores, final status
  - Edit mode: `lightning-combobox` for teams, `lightning-input` for scores/spread, `lightning-checkbox` for final
- Add Game / Add Multiple: `lightning-button` + `lightning-input type="number"`
- Delete game: Confirmation via `LightningConfirm` (replaces jQuery UI dialog)
- Dirty-state tracking: Track changes in component state, warn on navigation via `lightning-navigation`
- Validation: Call `GameService.validateAndSave()` which reuses extracted validation logic
- Locked game indicator: Visual badge or disabled state based on `Start_Time__c`
- Admin override: "Edit Locked" button for admin users
- **Complexity: High**

### 3.3 — `selections` (LWC — most complex)
_Replaces: Selections.page + PrintableSelections.page → SelectionController_
- **Layout:**
  - Player/Week selectors at top (admin sees player dropdown, players see only their own)
  - Game list below as responsive cards or a table
  - Each game shows: game number, matchup, spread, start time, lock status, selection toggle
- **Selection UI:**
  - Replace checkboxes with `lightning-button-stateful` or a custom toggle for Home/Away
  - Instant save on selection change via imperative `SelectionService.saveSelection()` call
  - Show `lightning-spinner` during save (replaces jQuery UI "Please Wait" dialog)
  - Disable selections for locked games (past start time)
- **Admin features:**
  - Player selector (`lightning-combobox`) to view/edit any player
  - Privileged edit mode bypasses lock
- **Print view:**
  - Add a "Print" button that opens a print-friendly view using `@media print` CSS
  - Or generate PDF server-side via Apex and serve as download
- **Mobile:**
  - Card-based layout stacks vertically
  - Large touch-friendly selection buttons
  - Swipe-friendly week navigation
- **Complexity: Very High**

---

## Phase 4: App Shell & Navigation

### 4.1 — Lightning App Page
- Create a new Lightning App (`NFLPool.app`) or update `PoolManager_Lightning`
- Configure with `lightning-tabset` or use the standard Lightning App Builder with tabs
- Tabs: Home, Selections, Results, My Account, Contact Info, Email, Message Board, Links
- Set up **Navigation Items** in App Manager
- Assign to appropriate profiles (Player, Pool Admin, System Admin)

### 4.2 — Responsive Design Strategy
- All components use `lightning-layout` with `size` / `small-size` / `medium-size` / `large-size` breakpoints
- SLDS utility classes for spacing, text sizing, and visibility (`slds-hide` at breakpoints)
- Tables switch to card/list view on small screens using `@media` queries or conditional rendering
- Test in Salesforce Mobile App (Lightning App available automatically if app is mobile-enabled)

### 4.3 — Home Page
- Create a Lightning `FlexiPage` for the home page
- Embed `homePageMessage` and `chatterMessageBoard` components
- Admin-only components (player management shortcuts) via component visibility filters

---

## Phase 5: Cleanup & Decommission

### 5.1 — Testing
- Write Jest unit tests for all LWC components (required for SFDX deployments)
- Update/write Apex tests for new service classes
- End-to-end manual testing across: Chrome, Safari, Firefox, Salesforce Mobile App (iOS + Android)
- Verify all profiles: System Admin, Pool Admin, Player

### 5.2 — Decommission Visualforce
- Remove VF page references from `PoolManager_Lightning` app tabs
- Add VF pages to `destructiveChanges.xml` for post-deployment deletion
- Delete `SoapUtils.cls` (auto-generated SOAP wrapper, no longer needed)
- Remove `jqueryui` and `jquery` static resources (no longer needed)
- Clean up old controller classes after confirming no references remain

### 5.3 — Documentation
- Update any internal documentation or help links
- Brief player communication about new UI

---

## Suggested Implementation Order (Summary)

| Order | Component | Complexity | Depends On |
|-------|-----------|-----------|------------|
| 0 | Apex Service Layer + config updates | Medium | — |
| 1 | `helpfulLinks` | Trivial | Phase 0 |
| 2 | `homePageMessage` | Trivial | Phase 0 |
| 3 | `contactInfo` | Simple | Phase 0 |
| 4 | `chatterMessageBoard` | Simple | Phase 0 |
| 5 | `myAccount` | Moderate | Phase 0 |
| 6 | `emailComposer` | Moderate | Phase 0 |
| 7 | `playerManagement` | Moderate | Phase 0 |
| 8 | `playerDetail` | High | Phase 0 |
| 9 | `results` (with charts) | High | Phase 0 |
| 10 | `games` | High | Phase 0 |
| 11 | `selections` | Very High | Phase 0 |
| 12 | App Shell & Navigation | Medium | All above |
| 13 | Cleanup & Decommission VF | Low | All above |

---

## Risk Considerations

1. **SOAP → @AuraEnabled migration** — The user-provisioning `webService` methods run in a separate transaction context (by design, to avoid mixed-DML errors). When converting to `@AuraEnabled`, you'll need to preserve this separation using `@future` or Queueable Apex.

2. **Chatter LWC support** — Verify the `forceChatter:feed` or equivalent LWC component is available in your org edition. If not, consider a custom feed component querying `FeedItem`.

3. **PDF generation** — `renderAs="PDF"` is VF-only. For printable selections, either use CSS `@media print` styling or server-side PDF generation (e.g., a VF page kept solely for PDF rendering, invoked via URL).

4. **Parallel operation** — You can run both VF and LWC side-by-side during migration. No need for a big-bang cutover. Add LWC tabs progressively and remove VF tabs once validated.

5. **Mobile App** — Lightning Web Components work in the Salesforce Mobile App automatically. However, test early — some features (like `lightning-datatable`) have different behavior on mobile. Card-based layouts are preferred for mobile.
