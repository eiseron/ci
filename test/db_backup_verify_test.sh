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
want '"$STACK_AUTOMATION_REPO" -b "$STACK_AUTOMATION_SHA"' "verify must install the gem fresh from automation_ref (not rely on the baked image)"

grep -qE 'services:' "$template" &&
  fail "verify must not need a postgres service; it is read-only on R2"

grep -qE 'PGHOST|PGUSER|PGPASSWORD' "$template" &&
  fail "verify must not need Postgres credentials; it is read-only on R2"

want 'export AWS_ACCESS_KEY_ID="$PROD_DRILL_AWS_ACCESS_KEY_ID"' "verify must export the drill R2 creds at runtime; a variables: mapping is overridden by a project-level AWS_ACCESS_KEY_ID (project vars outrank .gitlab-ci.yml vars)"
want 'export AWS_SECRET_ACCESS_KEY="$PROD_DRILL_AWS_SECRET_ACCESS_KEY"' "verify must export the drill R2 secret at runtime to beat a project-level AWS_SECRET_ACCESS_KEY"

grep -qE '^[[:space:]]+AWS_ACCESS_KEY_ID:' "$template" &&
  fail "verify must NOT set AWS creds via variables: (a project-level AWS_ACCESS_KEY_ID would override it); export in before_script instead"

want '$CI_PIPELINE_SOURCE == "schedule" && $BACKUP_JOB == "verify"' "verify must be gated to a schedule that sets BACKUP_JOB=verify (otherwise the weekly drill schedule would trigger the verify too)"
want '$CI_PIPELINE_SOURCE == "web" && $BACKUP_JOB == "verify"' "verify must be triggerable from a web pipeline that sets BACKUP_JOB=verify"
want "name: production" "verify must run under the production environment to receive the bucket vars"

want "extends: .notify_telegram_on_failure" "verify must extend the Telegram on-failure snippet so failures alert beyond the assignee email"
want "/templates/notify-telegram.yml" "verify must include the notify-telegram template that defines the extends target"

echo "PASS: db-backup-verify template wiring (read-only on R2, schedule-driven, gem-installed-fresh, Telegram-on-failure)"
