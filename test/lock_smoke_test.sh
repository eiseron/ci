#!/bin/sh
set -eu

template="templates/lock-smoke.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "lock-smoke:" "smoke job is missing"
want 'image: $STACK_GEM_RUNTIME_IMAGE' "smoke image must come from the lock (\$STACK_GEM_RUNTIME_IMAGE), not be hardcoded — same discipline the lock enforces everywhere else"
want '"$STACK_AUTOMATION_REPO"' "smoke must use STACK_AUTOMATION_REPO from the lock, not a hardcoded URL"
want '"$STACK_AUTOMATION_SHA"' "smoke must install the gem by SHA — the exact pattern templates use, that lints cannot catch"
want "gem uninstall -aIx eiseron_automation" "smoke must wipe the baked gem before installing the locked SHA, so the test exercises the install path and does not silently pass via baked"
want "gem specific_install" "smoke must exercise the specific_install pattern templates use"
want "command -v eiseron" "smoke must verify the binary lands on PATH after install"
want "needs: []" "smoke job is DAG-independent so it does not block on plan/apply"

grep -qE 'PROD_|PG|AWS_|TF_VAR' "$template" &&
  fail "smoke must not read prod secrets; it must run in any MR pipeline regardless of branch protection"

grep -qE '^[[:space:]]+image:[[:space:]]+(ruby|alpine|debian|ubuntu|node|python):' "$template" &&
  fail "smoke must not hardcode an upstream image — every image goes through the manifest+lock; use \$STACK_*_IMAGE"

want 'CI_PIPELINE_SOURCE == "merge_request_event"' "smoke must fire on every MR — that is the whole point of a preflight"
want 'CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH' "smoke must also fire on the default branch so a bad lock pushed straight to main is caught next pipeline"

grep -qE 'CI_COMMIT_BRANCH == "production"' "$template" &&
  fail "smoke should NOT run on production — production pipelines apply infra; a fresh-install smoke there wastes runner time"

want "STACK_AUTOMATION_REPO" "smoke must fail loudly if the lock did not provide STACK_AUTOMATION_REPO (means the consumer is on a pre-lock ci ref)"
want "STACK_GEM_RUNTIME_IMAGE" "smoke must fail loudly if the lock did not provide STACK_GEM_RUNTIME_IMAGE"

echo "PASS: lock-smoke template wiring (locked gem-runtime, wipe-then-install, MR + default branch, no prod secrets)"
