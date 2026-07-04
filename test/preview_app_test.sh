#!/bin/sh
set -eu

template="templates/preview-app.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want_count() {
  count=$(grep -cF -- "$1" "$template")
  test "$count" -eq "$2" || fail "$3 (expected $2 occurrences of '$1', got $count)"
}

want "build_image:" "build_image job is missing"
want "deploy_preview:" "deploy_preview job is missing"
want "deploy_main:" "deploy_main job is missing"
want "stop_preview:" "stop_preview job is missing"

want "executor" "build_image does not invoke kaniko executor"
want '$CI_REGISTRY_IMAGE/preview:$CI_COMMIT_REF_SLUG' "build_image does not push the ref-slug tag"
want '$CI_REGISTRY_IMAGE/preview:$CI_COMMIT_REF_SLUG-sha-$CI_COMMIT_SHORT_SHA' "build_image does not push the sha-stamped tag"

want '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH' "build_image is not gated on the default branch alongside MR events"
want '$CI_PIPELINE_SOURCE == "merge_request_event"' "deploy_preview is not MR-gated"

want_count "eiseron preview trigger" 3 "expected exactly 3 eiseron preview trigger calls (deploy_preview, deploy_main, stop_preview)"

want "PREVIEW_TRIGGER_ACTION: deploy" "no PREVIEW_TRIGGER_ACTION=deploy is set on any trigger job"
want "PREVIEW_TRIGGER_ACTION: stop" "stop_preview does not set PREVIEW_TRIGGER_ACTION=stop"
want "PREVIEW_TRIGGER_KIND: mr" "no PREVIEW_TRIGGER_KIND=mr is set on any trigger job"
want "PREVIEW_TRIGGER_KIND: main" "deploy_main does not set PREVIEW_TRIGGER_KIND=main"
want "PREVIEW_TRIGGER_REF: \$CI_COMMIT_REF_SLUG" "deploy_preview/stop_preview does not propagate the ref slug"
want 'PREVIEW_TRIGGER_REF: $[[ inputs.main_environment_name ]]' "deploy_main does not propagate main as the ref"
want_count "PREVIEW_TRIGGER_MR_IID: \$CI_MERGE_REQUEST_IID" 2 "PREVIEW_TRIGGER_MR_IID must appear in both deploy_preview and stop_preview"

want 'auto_stop_in: $[[ inputs.preview_auto_stop_in ]]' "deploy_preview does not parameterize auto_stop_in"
want "on_stop: stop_preview" "deploy_preview does not wire on_stop"
want "action: stop" "stop_preview does not declare the stop action on the environment"

want "url: https://\$CI_COMMIT_REF_SLUG-\$PREVIEW_DOMAIN_BASE" "deploy_preview url is not <ref>-<PREVIEW_DOMAIN_BASE>"
want 'url: https://$[[ inputs.main_environment_name ]]-$PREVIEW_DOMAIN_BASE' "deploy_main url is not <main>-<PREVIEW_DOMAIN_BASE>"

want "allow_failure: true" "preview jobs are not allow_failure (must never block a merge)"
want 'needs: ["build_image"]' "shared trigger anchor does not gate on build_image"

want "STACK_GEM_RUNTIME_IMAGE" "trigger jobs do not use the gem-runtime image (eiseron CLI must be available)"
want "local: /lock.yml" "preview-app does not include lock.yml (STACK_* vars unresolved)"

want "\$PREVIEW_REGISTRY_PASSWORD == null" "build_image lacks bootstrap guard on PREVIEW_REGISTRY_PASSWORD"
want "\$PREVIEW_DEPLOYER_TRIGGER_TOKEN == null" "trigger jobs lack bootstrap guard on PREVIEW_DEPLOYER_TRIGGER_TOKEN"

echo "PASS: preview-app template wiring (build + 3 thin triggers to eiseron CLI)"
