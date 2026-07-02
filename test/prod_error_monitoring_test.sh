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

want "prod-error-monitoring-build:" "error monitoring build job is missing"
want "/kaniko/executor" "build job does not use kaniko (daemonless; the ops runner has no docker daemon)"
want "platform/error-monitoring:" "build job does not push the image to our registry path"
want "local: /templates/prod-tenant.yml" "error monitoring does not reuse the shared prod-tenant job for its Postgres role/db"
want 'tenant_slug: "error_monitoring"' "error monitoring tenant is not provisioned under the error_monitoring slug"
want "prod-error-monitoring-deploy:" "error monitoring deploy job is missing"
want "job: prod-error-monitoring-build" "deploy does not depend on the build job (image must exist before deploy)"
want "kamal/error-monitoring/." "the canonical kamal/error-monitoring manifest is not copied from provisioning"
want '$STACK_PROVISIONING_REPO' "provisioning is not cloned for the canonical manifest"
want "kamal accessory reboot redis" "deploy does not reboot the redis accessory (boot is not idempotent on re-run)"
want "kamal deploy --skip-push" "deploy still builds (must --skip-push the kaniko-built image)"
want '$CI_COMMIT_BRANCH == "production"' "error monitoring jobs are not gated to the production branch"
want "when: manual" "deploy job is not manual"
want "name: production" "jobs do not run under the production environment"
want "resource_group: production" "jobs are not serialized via the production resource_group"

echo "PASS: prod-error-monitoring template wiring (kaniko build + skip-push deploy, production-manual)"
