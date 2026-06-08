#!/bin/sh
set -eu

template="templates/tofu-lint.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want 'tofu-lint:' "lint job is missing"
want 'eiseron tofu lint' "job does not invoke the eiseron gem command"
want '/iac:' "job does not run on the gem-bearing iac image"

echo "PASS: tofu-lint wiring"
