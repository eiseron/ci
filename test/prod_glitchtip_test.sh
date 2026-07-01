#!/bin/sh
set -eu

template="templates/prod-glitchtip.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "prod-glitchtip-deploy:" "glitchtip deploy job is missing"
want "local: /templates/prod-tenant.yml" "glitchtip does not reuse the shared prod-tenant job for its Postgres role/db"
want 'tenant_slug: "glitchtip"' "glitchtip tenant is not provisioned under the glitchtip slug"
want "kamal/glitchtip/." "the canonical kamal/glitchtip manifest is not copied from provisioning"
want '$STACK_PROVISIONING_REPO' "provisioning is not cloned for the canonical manifest"
want "kamal accessory boot redis" "glitchtip deploy does not boot the redis (valkey) accessory"
want "kamal deploy" "glitchtip deploy does not run kamal deploy"
want '$CI_COMMIT_BRANCH == "production"' "glitchtip deploy is not gated to the production branch"
want "when: manual" "glitchtip deploy is not manual"
want "needs: []" "glitchtip deploy is not DAG-independent (manual ops job must not be blocked by prior stages)"
want "name: production" "glitchtip deploy does not run under the production environment"
want "resource_group: production" "glitchtip deploy is not serialized via the production resource_group"

echo "PASS: prod-glitchtip template wiring (tenant reuse + kamal deploy, production-manual)"
