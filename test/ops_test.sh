#!/bin/sh
set -eu
f="templates/ops.yml"
fail() { echo "FAIL: $1"; exit 1; }
want() { grep -qF -- "$1" "$f" || fail "$2"; }

want 'local: /templates/tofu-lint.yml' "facade nao compoe tofu-lint"
want 'local: /templates/age-key-isolation.yml' "facade nao compoe age-key-isolation"
want 'local: /templates/ancestry-check.yml' "facade nao compoe ancestry-check"
want 'local: /templates/terraform-drift.yml' "facade nao compoe terraform-drift"
want 'fmt:' "facade nao define fmt"
want 'validate:' "facade nao define validate"
want 'plan:' "facade nao define plan"
want 'apply:' "facade nao define apply"
want '    - ancestry-check' "apply nao depende de ancestry-check (gate)"
want 'inputs.production_branch' "apply/workflow nao parametriza production_branch"

echo "PASS: ops facade wiring"
