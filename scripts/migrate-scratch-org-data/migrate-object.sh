#!/usr/bin/env bash
# Exports one sObject from a source org and upserts it into a target org,
# keyed on External_ID__c. Lookup fields are carried across orgs by pointing
# the CSV column at "<Field>__r.External_ID__c" and filling it with the
# *source* org's record Id for the parent — since the parent was itself
# imported with External_ID__c set to its source Id, Bulk API resolves the
# relationship without either org's real Ids ever needing to match.
#
# Usage: migrate-object.sh <config-file> <source-org> <target-org>
set -euo pipefail

CONFIG_FILE="${1:?Usage: migrate-object.sh <config-file> <source-org> <target-org>}"
SOURCE_ORG="${2:?Usage: migrate-object.sh <config-file> <source-org> <target-org>}"
TARGET_ORG="${3:?Usage: migrate-object.sh <config-file> <source-org> <target-org>}"

# shellcheck source=/dev/null
source "$CONFIG_FILE"

TMP_DIR="${TMPDIR:-/tmp}"
RAW_CSV="$TMP_DIR/${SOBJECT}_raw.csv"
IMPORT_CSV="$TMP_DIR/${SOBJECT}_import.csv"

echo "==> Exporting ${SOBJECT} from ${SOURCE_ORG}..."
sf data query \
  --query "SELECT ${QUERY_FIELDS} FROM ${SOBJECT} ${QUERY_ORDER:-}" \
  --target-org "${SOURCE_ORG}" \
  --result-format csv 2>/dev/null \
  | grep -E '^[a-zA-Z0-9]{15,18},' > "$RAW_CSV" || true

RECORD_COUNT=$(wc -l < "$RAW_CSV" | tr -d ' ')
if [ "$RECORD_COUNT" -eq 0 ]; then
  echo "    No ${SOBJECT} records found in ${SOURCE_ORG}; skipping."
  exit 0
fi

{
  echo "$CSV_HEADER"
  cat "$RAW_CSV"
} > "$IMPORT_CSV"
sed -i 's/\r$//' "$IMPORT_CSV"

echo "==> Upserting ${RECORD_COUNT} ${SOBJECT} record(s) into ${TARGET_ORG}..."
RESULT_JSON=$(sf data upsert bulk \
  --sobject "${SOBJECT}" \
  --file "$IMPORT_CSV" \
  --external-id "${EXTERNAL_ID_FIELD:-External_ID__c}" \
  --line-ending LF \
  --target-org "${TARGET_ORG}" \
  --wait 10 \
  --json)

PROCESSED=$(echo "$RESULT_JSON" | jq -r '.result.jobInfo.numberRecordsProcessed')
FAILED=$(echo "$RESULT_JSON" | jq -r '.result.jobInfo.numberRecordsFailed')
echo "    Processed: ${PROCESSED}, Failed: ${FAILED}"

if [ "$FAILED" != "0" ]; then
  echo "    ${SOBJECT}: ${FAILED} record(s) failed:"
  echo "$RESULT_JSON" | jq -r '.result.records.failedResults[] | "      - " + .sf__Error'
  exit 1
fi
