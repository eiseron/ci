#!/bin/sh
set -eu

template="templates/prod-deploy.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "prod-deploy:" "deploy job is missing"
want "eiseron prod deploy" "deploy job does not invoke the eiseron CLI"
want '"$STACK_AUTOMATION_REPO" -b "$STACK_AUTOMATION_SHA"' "the eiseron gem is not pinned to inputs.automation_ref"
want 'kamal/app/.' "the canonical kamal/app manifest is not copied from provisioning"
want '"$STACK_PROVISIONING_REPO" /tmp/provisioning' "provisioning is not cloned for the canonical manifest"

want 'APP_SERVICE: "$[[ inputs.app_service ]]"' "APP_SERVICE is not fed from inputs (committed, not a CI var)"
want 'APP_IMAGE: "$[[ inputs.app_image ]]"' "APP_IMAGE is not fed from inputs"
want 'APP_HOST: "$[[ inputs.app_host ]]"' "APP_HOST is not fed from inputs"
want 'APP_RELEASE_MODULE: "$[[ inputs.app_release_module ]]"' "APP_RELEASE_MODULE is not fed from inputs"
want 'PROD_TENANT_SLUG: "$[[ inputs.tenant_slug ]]"' "PROD_TENANT_SLUG is not fed from inputs"
want 'DB_URL_SCHEME: "$[[ inputs.db_url_scheme ]]"' "DB_URL_SCHEME is not fed from inputs"

grep -qE 'DATABASE_URL[[:space:]]*[:=]' "$template" &&
  fail "DATABASE_URL must not be set as a job variable; the gem rotates it into the kamal subprocess"

want 'PROD_ACTION == "deploy"' "deploy job is not gated on PROD_ACTION deploy"
want "needs: []" "deploy job is not DAG-independent (would block behind the manual tenant stage)"
want "name: production" "deploy job does not run under the production environment"
want "resource_group: production" "deploy job is not serialized via the production resource_group"

echo "PASS: prod-deploy template wiring (thin, inputs-fed, gem-rotated DATABASE_URL)"
