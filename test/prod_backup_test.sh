#!/bin/sh
set -eu

template="templates/prod-backup.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "prod-backup:" "backup job is missing"
want "eiseron prod backup" "backup job does not invoke the eiseron CLI"
want 'automation.git -b "$[[ inputs.automation_ref ]]"' "the eiseron gem is not pinned to inputs.automation_ref"
want 'kamal/app/.' "the canonical kamal/app manifest is not copied from provisioning"
want 'provisioning.git /tmp/provisioning' "provisioning is not cloned for the canonical manifest"

want 'APP_SERVICE: "$[[ inputs.app_service ]]"' "APP_SERVICE is not fed from inputs (committed, not a CI var)"
want 'PROD_TENANT_SLUG: "$[[ inputs.tenant_slug ]]"' "PROD_TENANT_SLUG is not fed from inputs"

grep -qE 'DATABASE_URL[[:space:]]*[:=]' "$template" &&
  fail "DATABASE_URL must not be set as a job variable; the gem rotates it into the kamal subprocess"

grep -qF 'PROD_TAG' "$template" &&
  fail "backup must not need PROD_TAG; it runs against the deployed accessory, not an app version"

want '$CI_COMMIT_BRANCH == "production"' "backup must run only on the production branch (operations against the live environment)"
want "when: manual" "backup job does not expose a manual button"

grep -qE 'CI_PIPELINE_SOURCE == "web"' "$template" &&
  fail "backup must not be a button on arbitrary web pipelines; it is gated to the production branch"
want "needs: []" "backup job is not DAG-independent (would not appear as a standalone button)"
want "name: production" "backup job does not run under the production environment"
want "resource_group: production" "backup job is not serialized via the production resource_group"

echo "PASS: prod-backup template wiring (manual button, inputs-fed, no PROD_TAG)"
