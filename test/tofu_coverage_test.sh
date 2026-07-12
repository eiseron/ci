#!/bin/sh
set -eu

template="templates/tofu-coverage.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "before_script: []" "before_script is not cleared -- consumers with a default: before_script (e.g. ops.yml) leak their secrets/init step in"
want "coverage: '/\[TOTAL\]" "coverage regex is missing or does not match the eiseron ci tofu-coverage output format"
want "eiseron ci tofu-coverage --modules-dir" "script does not invoke the tofu-coverage command with --modules-dir"

echo "PASS: tofu-coverage wiring"
