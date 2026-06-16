#!/bin/sh
set -eu

template="templates/go.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "eiseron go lint" "lint step should run the eiseron gem command"
want '$STACK_GO_TOOLS_IMAGE' "lint job should use the locked go-tools image"
want "go test ./... -race" "race test step is missing"

echo "PASS: go template wiring"
