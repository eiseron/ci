#!/bin/sh
set -eu

template="templates/prod-restore.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "prod-restore:" "restore job is missing"
want "eiseron prod restore" "restore job does not invoke the eiseron CLI"
want '"$STACK_AUTOMATION_REPO" -b "$STACK_AUTOMATION_SHA"' "the eiseron gem is not pinned to inputs.automation_ref"
want 'APP_SERVICE: "$[[ inputs.app_service ]]"' "APP_SERVICE is not fed from inputs"
want "ssh-add ~/.ssh/prod_deploy_key" "restore job does not set up the deploy ssh key"

grep -qF 'provisioning.git' "$template" &&
  fail "restore must not clone provisioning; it execs over ssh, it does not run kamal"

grep -qE 'PROD_RESTORE_KEY[[:space:]]*[:=]' "$template" &&
  fail "PROD_RESTORE_KEY must come from the run-pipeline variables, not be hardcoded"

want '$CI_COMMIT_BRANCH == "production" && $PROD_RESTORE_KEY && $PROD_RESTORE_CONFIRM' "restore must be gated to production and require both PROD_RESTORE_KEY and PROD_RESTORE_CONFIRM"
want "when: manual" "restore job must be a manual button"
want "name: production" "restore job does not run under the production environment"
want "resource_group: production" "restore job is not serialized via the production resource_group"

echo "PASS: prod-restore template wiring (production-only, manual, ssh exec, requires PROD_RESTORE_KEY)"
