#!/bin/sh
set -eu

template="templates/prod-tenant.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "prod-tenant:" "tenant job is missing"
want "eiseron prod tenant" "tenant job does not invoke the eiseron CLI"
want 'automation.git -b "$[[ inputs.automation_ref ]]"' "the eiseron gem is not pinned to inputs.automation_ref"
want 'PROD_TENANT_SLUG: "$[[ inputs.tenant_slug ]]"' "PROD_TENANT_SLUG is not fed from inputs"
want "prod_deploy_key" "tenant job does not install the prod SSH key"
want 'CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH' "tenant job is not gated to the default branch"
want "when: manual" "tenant job is not manual"
want 'if: $PREVIEW_MR_IID' "tenant job is not excluded from preview pipelines (must have no relation to prod)"
want "needs: []" "tenant job is not DAG-independent (manual ops job must not be blocked by prior stages)"
want "name: production" "tenant job does not run under the production environment"
want "resource_group: production" "tenant job is not serialized via the production resource_group"

grep -qF "provisioning.git" "$template" &&
  fail "tenant must not clone provisioning; it only runs psql over SSH"

echo "PASS: prod-tenant template wiring (psql over SSH, no manifest)"
