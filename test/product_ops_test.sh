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

absent() {
  if grep -qF -- "$1" "$template"; then fail "$2"; fi
}

want "/templates/db-backup-run.yml" "db-backup-run must be wired unconditionally now that k3s is the only runtime"
absent "/templates/prod-backup.yml" "prod-backup.yml was kamal-only and has been retired"
absent "runtime" "the runtime input is gone now that k3s is the only supported target"
absent "kamal" "kamal support has been retired; k3s is the only runtime"

want "namespace: \$[[ inputs.namespace ]]" "namespace input must reach db-backup-run"
want "run_stage: backup" "db-backup-run must share the same backup stage prod-deploy also feeds"

want 'default: "$PROD_APP_HOST"' "app_host must default to the CI var product_instance publishes, so ops repos stop hardcoding the same literal Terraform already knows"
want 'default: "$PROD_NAMESPACE"' "namespace must default to the CI var product_instance publishes"
want 'default: "$PROD_SLUG"' "app_name/tenant_slug/app_service must default to the CI var product_instance publishes"
want 'default: "$PROD_RELEASE_MODULE"' "app_release_module must default to the CI var product_instance publishes"
want "bin/\$PROD_SLUG eval '\$PROD_RELEASE_MODULE.Release.migrate'" "migrate_cmd must default to the standard bin/<slug> eval '<release_module>.Release.migrate' convention"

echo "PASS: product-ops wiring (k3s only, db-backup-run unconditional)"
