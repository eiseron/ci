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
want 'gem-runtime:$[[ inputs.image_tag ]]' "image must be the pinned gem-runtime tag"
want 'default: "v0.1.19"' "image_tag must default to the published gem-runtime tag"
want 'default: "postgres:18"' "pg_image must default to a throwaway postgres matching the prod major"
want 'name: production' "environment must be production so the drill key and R2 read creds resolve"
want 'GIT_STRATEGY: none' "drill needs no source checkout"
want 'timeout: 15 minutes' "job must cap its runtime so a hung service does not hold a runner"
want '[ "$n" -ge 30 ]' "postgres readiness wait must be bounded by an attempt cap"
want 'exit 1' "bounded readiness wait must fail the job when postgres never comes up"
want 'AWS_ACCESS_KEY_ID: "$PROD_DRILL_AWS_ACCESS_KEY_ID"' "R2 read creds must map from PROD_DRILL_AWS_* (AWS_* collides with the ops state backend)"
want 'AWS_SECRET_ACCESS_KEY: "$PROD_DRILL_AWS_SECRET_ACCESS_KEY"' "R2 read secret must map from PROD_DRILL_AWS_*"

want "if: '\$CI_PIPELINE_SOURCE == \"schedule\"'" "drill must run on the schedule (the alert)"
want "if: '\$CI_PIPELINE_SOURCE == \"web\"'" "drill must be triggerable manually from the web"
absent 'merge_request_event' "drill must not run on merge requests"
absent 'CI_DEFAULT_BRANCH' "drill must not run on every default-branch push"

echo "PASS: db-restore-drill wiring"
