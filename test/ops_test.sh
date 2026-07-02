#!/bin/sh
set -eu
f="templates/ops.yml"
fail() { echo "FAIL: $1"; exit 1; }
want() { grep -qF -- "$1" "$f" || fail "$2"; }

want 'local: /templates/tofu-lint.yml' "facade nao compoe tofu-lint"
want 'local: /templates/age-key-isolation.yml' "facade nao compoe age-key-isolation"
want 'local: /templates/ancestry-check.yml' "facade nao compoe ancestry-check"
want 'local: /templates/terraform-drift.yml' "facade nao compoe terraform-drift"
want 'TF_PLUGIN_CACHE_DIR' "facade nao configura o cache de providers"
want 'tf-providers' "facade nao tem a chave de cache de providers"
want 'fmt:' "facade nao define fmt"
want 'validate:' "facade nao define validate"
want 'plan:' "facade nao define plan"
want 'apply:' "facade nao define apply"
want '    - ancestry-check' "apply nao depende de ancestry-check (gate)"
want 'CI_COMMIT_BRANCH == "production"' "production branch nao esta hardcoded em apply/workflow"

want '$CI_PIPELINE_SOURCE != "trigger"' "plan/apply devem excluir source=trigger (ex.: preview-pages cross-project) para nao rodar tofu plan/apply em pipelines disparadas por trigger"
want '$CI_PIPELINE_SOURCE != "pipeline"' "plan/apply devem excluir source=pipeline (downstream/parent-child) pelo mesmo motivo"

want '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH' "plan deve continuar rodando no branch default (ancora de branch preservada, sem sobre-exclusao)"

echo "PASS: ops facade wiring"
