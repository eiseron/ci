#!/bin/sh
set -eu

template="templates/prod-deploy.yml"

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

want "prod-deploy:" "deploy job is missing"
want "eiseron prod deploy" "deploy job does not invoke the eiseron CLI"
want '"$STACK_AUTOMATION_REPO" -b "$STACK_AUTOMATION_SHA"' "the eiseron gem is not pinned to inputs.automation_ref"

want 'APP_SERVICE: "$[[ inputs.app_service ]]"' "APP_SERVICE is not fed from inputs (committed, not a CI var)"
want 'APP_IMAGE: "$[[ inputs.app_image ]]"' "APP_IMAGE is not fed from inputs"
want 'APP_HOST: "$[[ inputs.app_host ]]"' "APP_HOST is not fed from inputs"
want 'APP_RELEASE_MODULE: "$[[ inputs.app_release_module ]]"' "APP_RELEASE_MODULE is not fed from inputs"
want 'PROD_TENANT_SLUG: "$[[ inputs.tenant_slug ]]"' "PROD_TENANT_SLUG is not fed from inputs"
want 'DB_URL_SCHEME: "$[[ inputs.db_url_scheme ]]"' "DB_URL_SCHEME is not fed from inputs"

grep -qE 'DATABASE_URL[[:space:]]*[:=]' "$template" &&
  fail "DATABASE_URL must not be set as a job variable; the gem assembles it separately"

want 'PROD_ACTION == "deploy"' "deploy job is not gated on PROD_ACTION deploy"
want "needs: []" "deploy job is not DAG-independent (would block behind the manual tenant stage)"
want "name: production" "deploy job does not run under the production environment"
want "resource_group: production" "deploy job is not serialized via the production resource_group"

want "extends: .notify_telegram_on_failure" "deploy must alert on Telegram on failure (auto-deploys are unattended)"
want "/templates/notify-telegram.yml" "deploy must include the notify-telegram template that defines the extends target"

want 'default: "$PROD_SLUG"' "app_service must default to PROD_SLUG, published by product_instance"

absent "kamal" "kamal support has been retired; k3s is the only runtime"
absent "PROD_RUNTIME" "the runtime selector is gone now that k3s is the only target"
absent "PROD_SSH_PRIVATE_KEY" "the kamal SSH key install must be gone"
absent "STACK_PROVISIONING_REPO" "cloning the retired kamal/app manifest must be gone"

want 'PROD_IMAGE: "$[[ inputs.app_image ]]"' "Prod::Deploy needs PROD_IMAGE fed from inputs"
want 'PROD_MIGRATE_CMD: "$[[ inputs.migrate_cmd ]]"' "Prod::Deploy needs PROD_MIGRATE_CMD fed from inputs"
want 'base64 -d > ~/.kube/ca.crt' "the KUBECONFIG path must decode PROD_KUBE_CA into the cluster CA"
want '--server="$PROD_KUBE_HOST"' "KUBECONFIG must point at PROD_KUBE_HOST"
want '--token="$PROD_KUBE_TOKEN"' "KUBECONFIG must authenticate with PROD_KUBE_TOKEN"
want 'export KUBECONFIG="$HOME/.kube/config"' "the deploy must export KUBECONFIG for the kubectl Prod::Deploy"

echo "PASS: prod-deploy template wiring (k3s only, unconditional KUBECONFIG path, inputs-fed)"
