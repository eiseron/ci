#!/bin/sh
set -eu

template="templates/prod-observability.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want_absent() {
  grep -qF -- "$1" "$template" && fail "$2" || true
}

want "prod-observability-build:" "observability build job is missing"
want "/kaniko/executor" "build job does not use kaniko (daemonless; the ops runner has no docker daemon)"
want "before_script: []" "build job does not clear the inherited before_script (ops.yml sops/tofu setup fails on the kaniko image)"
want 'gitlab-ci-token:' "build job does not auth kaniko with the project CI job token"
want 'kamal/observability' "build job does not point the kaniko context at the observability manifest"
want '$CI_REGISTRY_IMAGE/observability:' "build job does not push to the project-owned writable registry"
want 'OBSERVABILITY_IMAGE: "$CI_PROJECT_PATH/observability"' "deploy image must be the host-less repo path (kamal prepends registry.server)"
want "prod-observability-deploy:" "observability deploy job is missing"
want "job: prod-observability-build" "deploy does not depend on the build job (image must exist before deploy)"
want "kamal/observability/." "the canonical kamal/observability manifest is not copied from provisioning"
want '$STACK_PROVISIONING_REPO' "provisioning is not cloned for the canonical manifest"
want "eiseron observability deploy" "deploy does not delegate to the gem command (deploy + root reset + accessory reboot + verify live in eiseron_automation now)"
want 'gem specific_install "$STACK_AUTOMATION_REPO" -b "$STACK_AUTOMATION_SHA"' "deploy does not install the pinned eiseron gem before invoking it"
want_absent "kamal accessory logs collector" "the inline shell diagnostic must be gone (moved into the gem command)"
want '$CI_COMMIT_BRANCH == "production"' "observability jobs are not gated to the production branch"
want "when: manual" "deploy job is not manual"
want "name: production" "jobs do not run under the production environment"
want "resource_group: production" "jobs are not serialized via the production resource_group"

want_absent "prod-tenant.yml" "observability must not provision a Postgres tenant (metadata is local + data on R2)"
want_absent "manage.py migrate" "observability has no Django migrations (OpenObserve migrates its own schema on boot)"
want_absent "create_superuser" "observability has no superuser bootstrap (OpenObserve seeds the root user from ZO_ROOT_USER_* on boot)"

echo "PASS: prod-observability template wiring (kaniko build + skip-push deploy + collector accessory, production-manual)"
