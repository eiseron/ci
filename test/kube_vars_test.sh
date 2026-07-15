#!/bin/sh
set -eu

template="templates/kube-vars.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "kube-vars-gate:" "job kube-vars-gate is missing"
want "eiseron prod kube-vars-gate" "gate must delegate to the automation gem, not inline bash"
want "gem specific_install" "gate must install the gem from the lock-pinned SHA"
want "STACK_AUTOMATION_SHA" "gate must pin the gem to the lock SHA, not a floating ref"
want "KUBE_VARS_PREFIX" "gate must map the variable prefix input into the gem env contract"
want "KUBE_VARS_API_TOKEN" "gate must map the consumer api token into the gem env contract"
want "needs: []" "gate must not wait on other jobs; it has to precede the plan"
want 'CI_PIPELINE_SOURCE != "schedule"' "gate must skip scheduled pipelines like the other ops jobs"
want "environment:" "gate needs the environment to receive the protected scoped variables"

grep -qE 'stage: \$\[\[ inputs.stage \]\]' "$template" ||
  fail "gate stage must be an input so consumers place it before their plan stage"

want 'CI_PIPELINE_SOURCE == "merge_request_event"' \
  "gate must also run on the promotion MR's own pipeline: CI_COMMIT_BRANCH is unset there, so the branch-push rule alone never fires and the plan job (which shares the environment-scoped vars) sees the stale endpoint"
want "CI_MERGE_REQUEST_TARGET_BRANCH_NAME" "the MR-pipeline rule must match the promotion's target branch"
want "CI_MERGE_REQUEST_SOURCE_BRANCH_NAME" "the MR-pipeline rule must match the promotion's source branch, mirroring the plan job's own rule"
want 'CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH' \
  "gate must also run on pushes to the default branch: ops.yml's plan job runs there too (a production-plan preview ahead of any promotion MR), so without this rule that pipeline hits the same stale-endpoint timeout the gate exists to prevent"

echo "PASS: kube-vars template wiring (gem-backed gate, lock-pinned, pre-plan)"
