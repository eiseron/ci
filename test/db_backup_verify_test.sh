#!/bin/sh
set -eu

template="templates/db-backup-verify.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "db-backup-verify:" "verify job is missing"
want "eiseron db backup verify" "verify job does not invoke the eiseron CLI"
want 'automation.git -b "$[[ inputs.automation_ref ]]"' "verify must install the gem fresh from automation_ref (not rely on the baked image)"

grep -qE 'services:' "$template" &&
  fail "verify must not need a postgres service; it is read-only on R2"

grep -qE 'PGHOST|PGUSER|PGPASSWORD' "$template" &&
  fail "verify must not need Postgres credentials; it is read-only on R2"

want 'AWS_ACCESS_KEY_ID: "$PROD_DRILL_AWS_ACCESS_KEY_ID"' "verify must consume the read-only drill R2 creds, not the backup write creds"
want 'AWS_SECRET_ACCESS_KEY: "$PROD_DRILL_AWS_SECRET_ACCESS_KEY"' "verify must consume the read-only drill R2 creds, not the backup write creds"

want 'CI_PIPELINE_SOURCE == "schedule"' "verify must run on a schedule (the primary trigger that delivers the alert)"
want 'CI_PIPELINE_SOURCE == "web"' "verify must also be runnable from a web pipeline for manual diagnostic"
want "name: production" "verify must run under the production environment to receive the bucket vars"

echo "PASS: db-backup-verify template wiring (read-only on R2, schedule-driven, gem-installed-fresh)"
