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

want "on_stop: preview-stop" "deploy environment does not wire on_stop to the stop job"
want "action: stop" "stop job is not an environment stop action"

want "PREVIEW_APP_STATE: present" "deploy job does not set state present"
want "PREVIEW_APP_STATE: absent" "stop job does not set state absent"

want "eiseron.provisioning.preview_app" "preview_app collection playbook is not invoked"
want 'provisioning.git,$[[ inputs.provisioning_ref ]]' "collection install is not pinned to inputs.provisioning_ref"

want "resource_group: preview/\$CI_MERGE_REQUEST_IID" "jobs are not serialized per MR via resource_group"

# The stop job must stay manual so a green deploy pipeline is not blocked by it.
stop_block=$(awk '/^preview-stop:/{f=1} f{print} ' "$template")
echo "$stop_block" | grep -qF "when: manual" || fail "stop job is not when: manual"

echo "PASS: preview-deploy template wiring"
