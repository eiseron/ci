#!/bin/sh
set -eu

template="templates/coverage-gate.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "stage: \$[[ inputs.stage ]]" "stage is not configurable -- consumers without a 'test' stage declared (e.g. ops.yml, org-ops.yml) would fail to lint"
want 'default: "test"' "stage input default is missing -- existing consumers (afinados, holter) rely on it to keep working unchanged"
want "needs:" "job does not depend on the test job via needs"
want "- \$[[ inputs.test_job_name ]]" "needs does not reference inputs.test_job_name"

echo "PASS: coverage-gate stage input"
