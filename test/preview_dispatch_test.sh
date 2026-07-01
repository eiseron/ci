#!/bin/sh
set -eu

template="templates/preview-dispatch.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "preview:" "dispatcher job is missing"

want 'PREVIEW_ACTION == "deploy"' "dispatcher does not fire on PREVIEW_ACTION=deploy"
want 'PREVIEW_ACTION == "stop"' "dispatcher does not fire on PREVIEW_ACTION=stop"
want 'PREVIEW_ACTION == "sweep"' "dispatcher does not fire on PREVIEW_ACTION=sweep"
want '$CI_PIPELINE_SOURCE == "schedule"' "dispatcher does not derive sweep from scheduled pipelines"
want '$BACKUP_JOB == null' "scheduled sweep must skip backup schedules (BACKUP_JOB set) so verify/drill runs do not also trigger a preview sweep"
want "PREVIEW_ACTION: sweep" "scheduled pipelines do not default PREVIEW_ACTION to sweep"

want "eiseron preview dispatch" "dispatcher does not invoke the eiseron CLI"

want "$[[ inputs.preview_stage ]]" "dispatcher does not parameterize preview_stage"
want "$[[ inputs.preview_timeout ]]" "dispatcher does not parameterize preview_timeout"

! grep -qF -- "chmod" "$template" || fail "dispatcher still chmods (vestigial of the bash deployer model)"
! grep -qF -- "deployer_dir" "$template" || fail "dispatcher still parameterizes deployer_dir (gem owns the dispatch now)"
! grep -qF -- "deployer_path" "$template" || fail "dispatcher still parameterizes deployer_path (gem owns the dispatch now)"

want "STACK_GEM_RUNTIME_IMAGE" "dispatcher does not use the gem-runtime image (eiseron CLI must be available)"
want "local: /lock.yml" "preview-dispatch does not include lock.yml (STACK_* vars unresolved)"

want "name: production" "dispatcher does not bind to the production environment (needed to receive production-scoped CI vars)"
want "needs: []" "dispatcher is not DAG-independent"

echo "PASS: preview-dispatch template wiring (thin → eiseron preview dispatch)"
