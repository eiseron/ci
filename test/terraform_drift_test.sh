#!/bin/sh
set -eu

template="templates/terraform-drift.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want 'terraform-drift:' "drift job is missing"
want 'plan -detailed-exitcode' "plan does not use detailed exit codes, drift would not fail the job"
want '-lock=false' "scheduled plan must not hold the state lock"
want '$CI_PIPELINE_SOURCE == "schedule" && $DRIFT_CHECK == "1"' "job is not gated to DRIFT_CHECK schedules"
want '$CI_COMMIT_BRANCH == "production" && $CI_PIPELINE_SOURCE != "trigger"' "drift must run on the production (applied) branch, not main (main is always ahead under deploy-by-promotion and would false-positive, blocking the promotion)"
want 'SOPS_AGE_KEY="$AGE_KEY"' "job does not decrypt the SOPS env file"
want 'action: prepare' "environment must use prepare to avoid fake deployment records"

echo "PASS: terraform-drift wiring"
