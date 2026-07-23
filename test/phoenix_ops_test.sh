#!/bin/sh
set -eu

template="templates/phoenix-ops.yml"

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

want "/templates/product-ops.yml" "product-ops must still be the base include"
want "/templates/preview-dispatch.yml" "preview-dispatch must still be wired for MR preview compose stacks"
want "/templates/preview-pages-deploy.yml" "preview-pages-deploy must be wired so a single include covers static-site previews too"
want "/templates/tofu-test.yml" "tofu-test must be wired so consumers stop including it separately"
want "/templates/tofu-coverage.yml" "tofu-coverage must be wired so consumers stop including it separately"
want "/templates/coverage-gate.yml" "coverage-gate must be wired so consumers stop including it separately"

want 'account_id: $[[ inputs.cloudflare_account_id ]]' "preview-pages-deploy must receive the account id from this facade's own input"
want '- if: '"'"'"$[[ inputs.cloudflare_account_id ]]" != ""'"'" "preview-pages-deploy must be skippable (rules gate) for products with no static-site preview"

want "chdirs: \$[[ inputs.tofu_chdirs ]]" "tofu-test must receive the chdirs list from this facade's own input"
want "test_job_name: tofu-coverage" "coverage-gate must be wired to the tofu-coverage job by name"

want "namespace: \$[[ inputs.namespace ]]" "namespace must pass through to product-ops for the k3s backup CronJob"

want 'default: "$PROD_APP_HOST"' "app_host must default to the CI var product_instance publishes, so ops repos stop hardcoding the same literal Terraform already knows"
want 'default: "$PROD_NAMESPACE"' "namespace must default to the CI var product_instance publishes"
want 'default: "$PROD_CLOUDFLARE_ACCOUNT_ID"' "cloudflare_account_id must default to the CI var product_instance publishes (scoped to all environments so this pipeline-level rule can read it)"
want 'default: "$PROD_SLUG"' "app_name/tenant_slug must default to the CI var product_instance publishes"
want 'default: "$PROD_RELEASE_MODULE"' "app_release_module must default to the CI var product_instance publishes"
want "bin/\$PROD_SLUG eval '\$PROD_RELEASE_MODULE.Release.setup'" "migrate_cmd must default to the standard bin/<slug> eval '<release_module>.Release.setup' convention"
want 'default: "$PROD_SLUG"' "app_service must default to PROD_SLUG"

absent "kamal" "kamal support has been retired; k3s is the only runtime"
absent "runtime:" "the runtime input is gone now that k3s is the only supported target"

echo "PASS: phoenix-ops facade wiring (k3s only, single include covers preview, tofu lint/test/coverage, backup)"
