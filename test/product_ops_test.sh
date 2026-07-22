#!/bin/sh
set -eu

template="templates/product-ops.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want "/templates/prod-backup.yml" "prod-backup must still be wired for kamal products"
want "/templates/db-backup-run.yml" "db-backup-run must be wired for k3s products"

want '- if: '"'"'"$[[ inputs.runtime ]]" == "kamal"'"'" "prod-backup must be gated to runtime == kamal, or it fires for k3s products too and depends on stack/provisioning's kamal/app path"
want '- if: '"'"'"$[[ inputs.runtime ]]" == "k3s"'"'" "db-backup-run must be gated to runtime == k3s"

want "namespace: \$[[ inputs.namespace ]]" "namespace input must reach db-backup-run"
want "run_stage: backup" "db-backup-run must share the same backup stage as prod-backup, not a new one"

want 'default: "$PROD_APP_HOST"' "app_host must default to the CI var product_instance publishes, so ops repos stop hardcoding the same literal Terraform already knows"
want 'default: "$PROD_NAMESPACE"' "namespace must default to the CI var product_instance publishes"

echo "PASS: product-ops wiring (prod-backup gated to kamal, db-backup-run gated to k3s)"
