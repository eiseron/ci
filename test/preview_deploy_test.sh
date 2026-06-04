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

# Triggered model: the IID comes from the passed PREVIEW_MR_IID, not from the
# app repo's own merge-request context, since the deploy runs in the ops repo.
want "PREVIEW_MR_IID" "jobs do not key off the passed PREVIEW_MR_IID"
grep -qF "CI_MERGE_REQUEST_IID" "$template" \
  && fail "template still keys off CI_MERGE_REQUEST_IID instead of PREVIEW_MR_IID"

want 'PREVIEW_ACTION == "deploy"' "deploy job is not gated on PREVIEW_ACTION deploy"
want 'PREVIEW_ACTION == "stop"' "stop job is not gated on PREVIEW_ACTION stop"

want "PREVIEW_APP_STATE: present" "deploy job does not set state present"
want "PREVIEW_APP_STATE: absent" "stop job does not set state absent"

want "action: stop" "stop job is not an environment stop action"

want "eiseron.provisioning.preview_app" "preview_app collection playbook is not invoked"
want 'provisioning.git,$[[ inputs.provisioning_ref ]]' "collection install is not pinned to inputs.provisioning_ref"
want "resource_group: preview/\$PREVIEW_MR_IID" "jobs are not serialized per MR via resource_group"
want "DATABASE_URL=" "DATABASE_URL is not assembled from the tenant credentials"
want "PREVIEW_TENANT_PASSWORD_ENC" "tenant password is not URL-encoded before going into DATABASE_URL"

echo "PASS: preview-deploy template wiring (trigger model)"
