#!/bin/sh
set -eu

template="templates/org-ops.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want_absent() {
  grep -qF -- "$1" "$template" && fail "$2" || true
}

want 'local: /templates/ops.yml' "facade nao compoe ops.yml"
want 'local: /templates/prod-platform.yml' "facade nao compoe prod-platform.yml"
want 'local: /templates/prod-error-monitoring.yml' "facade nao compoe prod-error-monitoring.yml"
want '"$[[ inputs.error_monitoring ]]" == "true"' "prod-error-monitoring nao e gateado pelo input error_monitoring"
want 'local: /templates/prod-observability.yml' "facade nao compoe prod-observability.yml"
want '"$[[ inputs.observability ]]" == "true"' "prod-observability nao e gateado pelo input observability"

grep -qE '^  - preview$' "$template" || fail "preview stage ausente (o deployer de pages-preview roda nele)"
grep -qE '^  - observability$' "$template" || fail "observability stage ausente (o deploy job da observabilidade roda nele)"

want 'apply:' "facade nao redeclara apply"
want '$TF_STATE_RM == null' "apply override nao tem o guard TF_STATE_RM (state-rm colide com apply em pipeline web na production)"

apply_block=$(awk '/^apply:/{flag=1} flag && /^[a-zA-Z]/ && !/^apply:/{exit} flag{print}' "$template")
echo "$apply_block" | grep -qF 'needs: []' && fail "apply override carrega 'needs: []' — quebra o gate de ancestry-check em production (regressao do bug do !49)" || true

want 'runner-fmt:' "runner-fmt missing"
want 'runner-validate:' "runner-validate missing"
want 'runner-plan:' "runner-plan missing"
want 'runner-apply:' "runner-apply missing"
want 'runner-provision:' "runner-provision missing"
want 'preview-provision:' "preview-provision missing"
want 'keyserver-provision:' "keyserver-provision missing"
want 'prod-provision:' "prod-provision missing"
want 'rotate-tokens:' "rotate-tokens missing"
want 'rotate-sa-tokens:' "rotate-sa-tokens missing"
want 'state-rm:' "state-rm missing"

want 'RUNNER_HOSTNAME: $[[ inputs.runner_hosts ]]' "runner-provision nao usa parallel:matrix sobre runner_hosts"
want 'PREVIEW_HOSTNAME: $[[ inputs.preview_hosts ]]' "preview-provision nao usa parallel:matrix sobre preview_hosts"
want 'KEYSERVER_HOSTNAME: $[[ inputs.keyserver_hosts ]]' "keyserver-provision nao usa parallel:matrix sobre keyserver_hosts"
want 'PROD_HOSTNAME: $[[ inputs.prod_hosts ]]' "prod-provision nao usa parallel:matrix sobre prod_hosts"

want 'if [ -z "$RUNNER_HOSTNAME" ]' "runner-provision sem sentinel de host vazio (matrix com default [""] entraria no caminho ativo)"
want 'if [ -z "$PREVIEW_HOSTNAME" ]' "preview-provision sem sentinel de host vazio"
want 'if [ -z "$KEYSERVER_HOSTNAME" ]' "keyserver-provision sem sentinel de host vazio"
want 'if [ -z "$PROD_HOSTNAME" ]' "prod-provision sem sentinel de host vazio"

want '$ORG_RUNNER_STATE == "true"' "runner-state nao gateia os runner-* jobs"
want '$ORG_ROTATE_TOKEN_TARGETS != ""' "rotate-tokens nao e gateado por rotate_token_targets nao-vazio"
want '$ORG_ROTATE_SA_TOKEN_TARGETS != ""' "rotate-sa-tokens nao e gateado por rotate_sa_token_targets nao-vazio"

want 'tags:
    - saas-linux-small-amd64' "runner-apply / runner-provision nao saem do self-hosted (job que pode recriar o proprio self-hosted runner precisa rodar em SaaS)"

echo "PASS: org-ops facade wiring"
