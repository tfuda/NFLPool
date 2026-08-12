#!/usr/bin/env bash
# Runs every object config under objects/ in filename order (hence the
# numeric prefixes — parents must import before the children that
# reference them). Add a new NN-object.conf file to extend the migration.
#
# Usage: migrate-all.sh <source-org> <target-org>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ORG="${1:?Usage: migrate-all.sh <source-org> <target-org>}"
TARGET_ORG="${2:?Usage: migrate-all.sh <source-org> <target-org>}"

for CONFIG in "$SCRIPT_DIR"/objects/*.conf; do
  "$SCRIPT_DIR/migrate-object.sh" "$CONFIG" "$SOURCE_ORG" "$TARGET_ORG"
done

echo "==> All objects migrated from ${SOURCE_ORG} to ${TARGET_ORG}."
