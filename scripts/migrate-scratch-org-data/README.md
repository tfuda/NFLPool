# Scratch Org Data Migration

Copies reference/game data between orgs (e.g. `sysadmin` → a fresh scratch
org) without a full data-loader setup. Built for re-populating a scratch org
after it expires.

## Usage

```
./migrate-all.sh <source-org-alias> <target-org-alias>
```

Example:

```
./migrate-all.sh sysadmin NFLPoolScratch2
```

Or run a single object:

```
./migrate-object.sh objects/02-game.conf sysadmin NFLPoolScratch2
```

## How it works

Every migrated object has an `External_ID__c` (Text(18), unique, External ID)
field. On import, `External_ID__c` is set to the **source org's record Id**.
That gives every record a stable, cross-org identifier without the two orgs'
real Salesforce Ids ever needing to match.

Lookup fields are carried across by writing the CSV column as
`<Field>__r.External_ID__c` and filling it with the *source* org's Id for
the parent record. Bulk API resolves that against the target org's
`External_ID__c` values — which only works if the parent object was
imported first. That's why configs are numbered (`01-team.conf` before
`02-game.conf`) and `migrate-all.sh` runs them in filename order.

Formula fields (e.g. `Game__c.Winner__c`, `Points__c`, `Locked__c`) are
never queried or imported — they recompute on their own in the target org.

## Adding a new object

1. Confirm the object has (or add) a unique External ID field named
   `External_ID__c`.
2. Add `objects/NN-object.conf` with a number higher than any object it
   depends on:
   ```
   SOBJECT="Selection__c"
   QUERY_FIELDS="Id, Team__c, Game__c, Player__c, Points__c"
   QUERY_ORDER="ORDER BY Game__c"
   CSV_HEADER="External_ID__c,Team__r.External_ID__c,Game__r.External_ID__c,Player__r.External_ID__c,Points__c"
   EXTERNAL_ID_FIELD="External_ID__c"
   ```
   (Exclude any formula/rollup fields from `QUERY_FIELDS`/`CSV_HEADER`.)
3. Run `migrate-all.sh` again — already-imported objects just get
   re-upserted (idempotent, matched on `External_ID__c`).

## Known gotchas

- **Windows line endings**: the script strips CR and passes
  `--line-ending LF` explicitly to `sf data upsert bulk`. Bulk API v2
  defaults to CRLF on Windows and errors on mismatched line endings if you
  ever edit this script and drop that flag.
- **User references**: objects with lookups to `User` (e.g.
  `Player__c.User__c`) aren't handled by this pattern — scratch org users
  don't exist in the source org. Those need to be mapped by hand or
  nulled out.
- Requires the Salesforce CLI (`sf`) authenticated against both orgs.
