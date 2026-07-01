#!/bin/sh
set -eu

template="templates/prod-error-monitoring.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "prod-error-monitoring-deploy:" "error monitoring deploy job is missing"
want "local: /templates/prod-tenant.yml" "error monitoring does not reuse the shared prod-tenant job for its Postgres role/db"
want 'tenant_slug: "error_monitoring"' "error monitoring tenant is not provisioned under the error_monitoring slug"
want "kamal/error-monitoring/." "the canonical kamal/error-monitoring manifest is not copied from provisioning"
want '$STACK_PROVISIONING_REPO' "provisioning is not cloned for the canonical manifest"
want "kamal accessory boot redis" "error monitoring deploy does not boot the redis (valkey) accessory"
want "kamal deploy" "error monitoring deploy does not run kamal deploy"
want '$CI_COMMIT_BRANCH == "production"' "error monitoring deploy is not gated to the production branch"
want "when: manual" "error monitoring deploy is not manual"
want "needs: []" "error monitoring deploy is not DAG-independent (manual ops job must not be blocked by prior stages)"
want "name: production" "error monitoring deploy does not run under the production environment"
want "resource_group: production" "error monitoring deploy is not serialized via the production resource_group"

echo "PASS: prod-error-monitoring template wiring (tenant reuse + kamal deploy, production-manual)"
