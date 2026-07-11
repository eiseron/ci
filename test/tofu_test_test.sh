#!/bin/sh
set -eu

template="templates/tofu-test.yml"

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
want 'tofu -chdir="$CHDIR" test' "test step is missing"

echo "PASS: tofu-test matrix wiring"
