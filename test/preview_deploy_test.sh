#!/bin/sh
set -eu

template="templates/preview-deploy.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "preview-deploy:" "deploy job is missing"
want "preview-stop:" "stop job is missing"

want "eiseron preview deploy" "deploy job does not invoke the eiseron CLI"
want "eiseron preview stop" "stop job does not invoke the eiseron CLI"
want 'automation.git -b "$[[ inputs.automation_ref ]]"' "the eiseron gem is not pinned to inputs.automation_ref"
want 'provisioning.git,$[[ inputs.provisioning_ref ]]' "collection install is not pinned to inputs.provisioning_ref"

want 'PREVIEW_ACTION == "deploy"' "deploy job is not gated on PREVIEW_ACTION deploy"
want 'PREVIEW_ACTION == "stop"' "stop job is not gated on PREVIEW_ACTION stop"
want "EISERON_PREVIEW_ZONE" "deploy does not pass the preview zone to the CLI"
want "action: stop" "stop job is not an environment stop action"
want "resource_group: preview/\$PREVIEW_MR_IID" "jobs are not serialized per MR via resource_group"

echo "PASS: preview-deploy template wiring (thin, gem-backed)"
