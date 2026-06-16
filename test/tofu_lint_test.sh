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

absent() {
  if grep -qF -- "$1" "$template"; then fail "$2"; fi
}

want 'tofu-lint:' "lint job is missing"
want 'eiseron tofu lint' "job does not invoke the eiseron gem command"
want '$STACK_IAC_IMAGE' "job does not run on the gem-bearing iac image"
want 'before_script: []' "tofu-lint nao pode herdar o sops-decrypt do before_script default"
want 'CI_PIPELINE_SOURCE == "merge_request_event"' "tofu-lint must run on merge request pipelines"
absent 'CI_DEFAULT_BRANCH' "tofu-lint must not run after merge (no default-branch rule)"

echo "PASS: tofu-lint wiring"
