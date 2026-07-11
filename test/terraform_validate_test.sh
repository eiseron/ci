#!/bin/sh
set -eu

template="templates/terraform-validate.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "type: array" "matrix input is not typed as an array"
want "parallel:" "job does not use parallel:"
want "matrix: \$[[ inputs.matrix ]]" "matrix does not iterate over inputs.matrix"
want 'tofu -chdir="$CHDIR" validate' "validate step is missing"
want 'tofu -chdir="$CHDIR" fmt -check -recursive' "fmt check step is missing"
want "before_script: []" "before_script is not cleared -- consumers with a default: before_script (e.g. ops.yml) leak their secrets/init step in"
want "changes:" "rules do not scope by changed paths -- every module reruns on every MR regardless of what changed"
want "- \$WATCH/**/*" "changes pattern does not use the per-entry WATCH path"

echo "PASS: terraform-validate matrix wiring"
