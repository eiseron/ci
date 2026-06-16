#!/bin/sh
set -eu

template="templates/preview-sweep.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "preview-sweep:" "sweep job is missing"
want "eiseron preview sweep" "sweep does not invoke the eiseron CLI"
want '"$STACK_AUTOMATION_REPO" -b "$STACK_AUTOMATION_SHA"' "the eiseron gem is not pinned to inputs.automation_ref"
want 'git+$STACK_PROVISIONING_REPO,$STACK_PROVISIONING_SHA' "collection install is not pinned to inputs.provisioning_ref"
want "EISERON_PREVIEW_SCAN_PROJECT" "sweep does not pass the scan project to the CLI"
want 'CI_PIPELINE_SOURCE == "schedule"' "sweep does not run on a schedule"

echo "PASS: preview-sweep template wiring (thin, gem-backed)"
