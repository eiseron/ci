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

want "type: array" "chdirs input is not typed as an array"
want "parallel:" "job does not use parallel:"
want "- CHDIR: \$[[ inputs.chdirs ]]" "matrix does not iterate over inputs.chdirs"
want 'tofu -chdir="$CHDIR" validate' "validate step is missing"
want 'tofu -chdir="$CHDIR" fmt -check -recursive' "fmt check step is missing"
want "before_script: []" "before_script is not cleared -- consumers with a default: before_script (e.g. ops.yml) leak their secrets/init step in"

echo "PASS: terraform-validate matrix wiring"
