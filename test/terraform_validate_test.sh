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

want 'terraform-validate$[[ inputs.name ]]:' "job name does not use the name suffix input"
want "name:" "name input is missing"
want 'terraform -chdir="$[[ inputs.chdir ]]" validate' "validate step is missing"
want 'terraform -chdir="$[[ inputs.chdir ]]" fmt -check -recursive' "fmt check step is missing"

echo "PASS: terraform-validate name-suffix wiring"
