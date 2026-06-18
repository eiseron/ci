#!/bin/sh
set -eu

template="templates/workers.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "spec:" "template must declare its inputs via the spec header"
want "workers_dir:" "consumers must be able to override the directory holding the worker scripts"
want "include:" "template must re-use stack helpers via include"
want "/lock.yml" "template must include the lock so STACK_* vars are exposed to consumers"
want "/templates/release.yml" "template must include release.yml so the consumer ships VERSION-driven tags"
want "worker-lint:" "the worker-lint job must exist"
want "node --check" "the worker-lint job must syntax-check each worker via node --check"
want '$STACK_NODE_IMAGE' "the worker-lint job must run on the lock-pinned node image (not a hardcoded tag)"
want '$[[ inputs.workers_dir ]]' "the worker-lint job must respect the configurable workers_dir input"
want 'merge_request_event' "the worker-lint job must run on every MR pipeline"
want 'CI_DEFAULT_BRANCH' "the worker-lint job must also run on the default branch so post-merge regressions are caught"
echo "OK"
