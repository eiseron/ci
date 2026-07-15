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

echo "PASS: kube-vars template wiring (gem-backed gate, lock-pinned, pre-plan)"
