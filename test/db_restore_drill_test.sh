#!/bin/sh
set -eu

template="templates/db-restore-drill.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

absent() {
  if grep -qF -- "$1" "$template"; then fail "$2"; fi
}

want 'db-restore-drill:' "drill job is missing"
want 'eiseron db restore-drill' "job must run the gem drill command"
want '$STACK_GEM_RUNTIME_IMAGE' "image must be the pinned gem-runtime tag"
want '- name: $STACK_POSTGRES_IMAGE' "drill must run against the lock-pinned postgres (matching prod major), not a per-consumer override"

grep -qE '^[[:space:]]+pg_image:' "$template" &&
  fail "pg_image input was removed — postgres now comes from the lock (manifest.yml), so consumers cannot diverge from prod major by accident"
want 'name: production' "environment must be production so the drill key and R2 read creds resolve"
want 'GIT_STRATEGY: none' "drill needs no source checkout"
want 'timeout: 15 minutes' "job must cap its runtime so a hung service does not hold a runner"
want '[ "$n" -ge 30 ]' "postgres readiness wait must be bounded by an attempt cap"
want 'exit 1' "bounded readiness wait must fail the job when postgres never comes up"
want 'export AWS_ACCESS_KEY_ID="$PROD_DRILL_AWS_ACCESS_KEY_ID"' "drill must export the R2 read creds at runtime; AWS_* collides with the project-level AWS_ACCESS_KEY_ID, which outranks .gitlab-ci.yml variables: and would otherwise win"
want 'export AWS_SECRET_ACCESS_KEY="$PROD_DRILL_AWS_SECRET_ACCESS_KEY"' "drill must export the R2 read secret at runtime to beat the project-level AWS_SECRET_ACCESS_KEY"

grep -qE '^[[:space:]]+AWS_ACCESS_KEY_ID:' "$template" &&
  fail "drill must NOT set AWS creds via variables: (a project-level AWS_ACCESS_KEY_ID would override it); export in before_script instead"

want "if: '\$CI_PIPELINE_SOURCE == \"schedule\" && \$BACKUP_JOB == \"drill\"'" "drill must be gated to a schedule that sets BACKUP_JOB=drill (otherwise the daily verify schedule would trigger the drill too)"
want "if: '\$CI_PIPELINE_SOURCE == \"web\" && \$BACKUP_JOB == \"drill\"'" "drill must be triggerable from a web pipeline that sets BACKUP_JOB=drill"
absent 'merge_request_event' "drill must not run on merge requests"
absent 'CI_DEFAULT_BRANCH' "drill must not run on every default-branch push"

echo "PASS: db-restore-drill wiring"
