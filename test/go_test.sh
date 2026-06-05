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

want "gofmt -l" "gofmt check step is missing"
want "go vet ./..." "go vet step is missing"
want "golangci-lint run ./..." "golangci-lint step is missing"
want "go test ./... -race" "race test step is missing"
want "line comments are not allowed in source" "comment lint step is missing"

echo "PASS: go template wiring"
