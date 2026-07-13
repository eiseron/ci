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

want "prod-deploy:" "deploy job is missing"
want "eiseron prod deploy" "deploy job does not invoke the eiseron CLI"
want '"$STACK_AUTOMATION_REPO" -b "$STACK_AUTOMATION_SHA"' "the eiseron gem is not pinned to inputs.automation_ref"
want 'kamal/app/.' "the canonical kamal/app manifest is not copied from provisioning"
want '"$STACK_PROVISIONING_REPO" /tmp/provisioning' "provisioning is not cloned for the canonical manifest"

want 'APP_SERVICE: "$[[ inputs.app_service ]]"' "APP_SERVICE is not fed from inputs (committed, not a CI var)"
want 'APP_IMAGE: "$[[ inputs.app_image ]]"' "APP_IMAGE is not fed from inputs"
want 'APP_HOST: "$[[ inputs.app_host ]]"' "APP_HOST is not fed from inputs"
want 'APP_RELEASE_MODULE: "$[[ inputs.app_release_module ]]"' "APP_RELEASE_MODULE is not fed from inputs"
want 'PROD_TENANT_SLUG: "$[[ inputs.tenant_slug ]]"' "PROD_TENANT_SLUG is not fed from inputs"
want 'DB_URL_SCHEME: "$[[ inputs.db_url_scheme ]]"' "DB_URL_SCHEME is not fed from inputs"

grep -qE 'DATABASE_URL[[:space:]]*[:=]' "$template" &&
  fail "DATABASE_URL must not be set as a job variable; the gem rotates it into the kamal subprocess"

want 'PROD_ACTION == "deploy"' "deploy job is not gated on PROD_ACTION deploy"
want "needs: []" "deploy job is not DAG-independent (would block behind the manual tenant stage)"
want "name: production" "deploy job does not run under the production environment"
want "resource_group: production" "deploy job is not serialized via the production resource_group"

want "extends: .notify_telegram_on_failure" "deploy must alert on Telegram on failure (auto-deploys are unattended)"
want "/templates/notify-telegram.yml" "deploy must include the notify-telegram template that defines the extends target"

want 'default: "kamal"' "runtime input must default to kamal for back-compat with kamal products"
want 'options: ["kamal", "k3s"]' "runtime input must be constrained to kamal|k3s"
want 'PROD_RUNTIME: "$[[ inputs.runtime ]]"' "the runtime selector must reach the job as PROD_RUNTIME"
want 'if [ "$PROD_RUNTIME" = "k3s" ]; then' "the deploy path must branch on the runtime selector"

want 'PROD_IMAGE: "$[[ inputs.app_image ]]"' "k3s Prod::Deploy needs PROD_IMAGE fed from inputs"
want 'PROD_MIGRATE_CMD: "$[[ inputs.migrate_cmd ]]"' "k3s Prod::Deploy needs PROD_MIGRATE_CMD fed from inputs"
want 'base64 -d > ~/.kube/ca.crt' "k3s path must decode PROD_KUBE_CA into the cluster CA"
want '--server="$PROD_KUBE_HOST"' "k3s KUBECONFIG must point at PROD_KUBE_HOST"
want '--token="$PROD_KUBE_TOKEN"' "k3s KUBECONFIG must authenticate with PROD_KUBE_TOKEN"
want 'export KUBECONFIG="$HOME/.kube/config"' "k3s path must export KUBECONFIG for the kubectl Prod::Deploy"

grep -q 'PROD_SSH_PRIVATE_KEY' "$template" ||
  fail "kamal path must keep the SSH key install (back-compat with kamal products)"

k3s_line=$(grep -n 'PROD_RUNTIME.*=.*"k3s"' "$template" | head -1 | cut -d: -f1)
ssh_line=$(grep -n 'ssh-add ~/.ssh/prod_deploy_key' "$template" | head -1 | cut -d: -f1)
[ -n "$k3s_line" ] && [ -n "$ssh_line" ] && [ "$ssh_line" -gt "$k3s_line" ] ||
  fail "kamal SSH setup must live in the else branch, not run on the k3s path"

kube_line=$(grep -n 'set-credentials prod --token' "$template" | head -1 | cut -d: -f1)
clone_line=$(grep -n '"$STACK_PROVISIONING_REPO" /tmp/provisioning' "$template" | head -1 | cut -d: -f1)
[ -n "$kube_line" ] && [ -n "$clone_line" ] && [ "$clone_line" -gt "$kube_line" ] ||
  fail "k3s path must not clone the kamal config (that belongs to the else branch)"

echo "PASS: prod-deploy template wiring (kamal default + k3s KUBECONFIG path, both inputs-fed)"
