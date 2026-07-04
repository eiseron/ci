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
want 'git merge-base --is-ancestor HEAD origin/main' "guard does not allow behind-trunk (ancestor) runs via SHA ancestry"
want 'git diff --quiet HEAD origin/main' "guard drops the content-diff fallback (needed so equality survives a squashed promotion, where SHA ancestry breaks)"
want 'CI_MERGE_REQUEST_TARGET_BRANCH_NAME' "guard does not run pre-merge on MRs targeting the production branch"
want '"production"' "production branch must be hardcoded"
want 'origin main' "trunk branch must be hardcoded as 'main' in the git fetch / diff"
want 'GIT_DEPTH' "guard needs full history for the ancestry check"

echo "PASS: ancestry-check wiring"
