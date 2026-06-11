#!/bin/sh
set -eu

template="templates/prod-platform.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "prod-platform:" "platform job is missing"
want "kamal accessory boot db" "platform job does not boot the shared db accessory"
want "kamal proxy boot" "platform job does not boot the shared kamal-proxy"
want "kamal/platform/." "the canonical kamal/platform manifest is not copied from provisioning"
want "provisioning.git" "provisioning is not cloned for the canonical manifest"
want 'CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH' "platform job is not gated to the default branch"
want "when: manual" "platform job is not manual"
want "name: production" "platform job does not run under the production environment"
want "resource_group: production" "platform job is not serialized via the production resource_group"

echo "PASS: prod-platform template wiring (shared db + proxy, main-manual)"
