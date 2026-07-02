#!/bin/sh
set -eu

template="templates/preview-pages-trigger.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

reject() {
  grep -qF -- "$1" "$template" && fail "$2" || true
}

want "trigger_preview:" "trigger_preview job is missing"
want "stop_preview:" "stop_preview job is missing"

want "eiseron preview pages-trigger" "does not delegate to the eiseron CLI"
want "PREVIEW_TRIGGER_ACTION: deploy" "trigger_preview does not request a deploy"
want "PREVIEW_TRIGGER_ACTION: stop" "stop_preview does not request a stop"
want 'PREVIEW_DIST_DIR: "$[[ inputs.dist_dir ]]"' "does not pass the dist dir to the gem"
want "job: \$[[ inputs.build_job ]]" "trigger_preview does not need the build artifact"

want '$CI_PIPELINE_SOURCE == "merge_request_event"' "trigger_preview is not MR-gated"
want "when: manual" "stop_preview is not manual"
want "on_stop: stop_preview" "does not wire on_stop"
want ".pages.dev" "environment URL is not the deterministic pages.dev preview host"
want "action: stop" "stop_preview does not stop the environment"
want "STACK_GEM_RUNTIME_IMAGE" "does not run on the gem-runtime image (which ships the eiseron CLI)"

reject "wrangler" "the trigger side must not run wrangler (the deployer does)"
reject "CLOUDFLARE" "the trigger side must not reference the Cloudflare token"
