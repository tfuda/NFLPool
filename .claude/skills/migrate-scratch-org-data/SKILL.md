---
name: migrate-scratch-org-data
description: Populate a fresh NFLPool scratch org with reference data (Teams, Games, ...) copied from another org, e.g. after a scratch org expired and was recreated. Use when the user wants to export/import/migrate/copy data between NFLPool orgs, or repopulate a new scratch org.
---

# Migrate Scratch Org Data

Runs `scripts/migrate-scratch-org-data/migrate-all.sh` to copy reference
data from a source org (typically `sysadmin`) into a target org (typically
a newly created scratch org).

## When to use this

The user has just created (or recreated) a scratch org for the
Visualforce-to-Lightning migration project and needs it populated with
Team/Game/etc. data from another org — most often after the previous
scratch org expired.

## How to run it

```bash
./scripts/migrate-scratch-org-data/migrate-all.sh <source-org-alias> <target-org-alias>
```

Confirm both org aliases exist first with `sf org list --json` (a stale
expired scratch org's alias can linger in the list without being
connectable). Ask the user which source/target orgs to use if not already
clear from context — do not assume.

This runs every object config under `objects/` in filename order (parents
before children — see the numeric prefixes). It's safe to re-run; imports
are upserts keyed on each object's `External_ID__c`.

## Currently covered objects

Check `scripts/migrate-scratch-org-data/objects/` for the current list —
it grows over time. As of this writing: `Team__c`, `Game__c`.

## Extending to a new object

Read `scripts/migrate-scratch-org-data/README.md` — it documents the
`External_ID__c` cross-org relationship pattern and the exact steps for
adding a new object config. Don't re-derive the pattern from scratch;
follow what's already documented there.

## Known limitations

- Objects with lookups to `User` (e.g. `Player__c.User__c`) aren't handled
  by the generic pattern — flag this to the user rather than silently
  guessing a mapping.
- Formula fields are never part of the migrated field list.
