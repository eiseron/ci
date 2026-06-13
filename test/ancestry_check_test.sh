#!/bin/sh
set -eu

template="templates/ancestry-check.yml"

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

want 'ancestry-check:' "guard job is missing"
want 'git diff --quiet HEAD origin/' "guard is not content-based (must diff the trunk tree)"
want 'CI_MERGE_REQUEST_TARGET_BRANCH_NAME' "guard does not run pre-merge on MRs targeting the production branch"
want 'inputs.production_branch' "production branch must be parameterized"
want 'GIT_DEPTH' "guard needs full history for the content diff"
absent 'merge-base' "guard must be content-based, not SHA ancestry (breaks under squash)"

echo "PASS: ancestry-check wiring"
