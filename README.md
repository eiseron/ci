# ci

Reusable GitLab CI templates shared across Eiseron products. Consumers
`include:` a template pinned to a tag — never a moving branch.

## templates/phoenix.yml

`lint` + `test` jobs for an Eiseron Phoenix project, running on the shared
`elixir-builder` image and a Postgres service.

```yaml
include:
  - project: eiseron/stack/ci
    file: /templates/phoenix.yml
    ref: v0.1.0
    inputs:
      app_name: myapp

stages:
  - lint
  - test
```

Inputs:

| input | default | purpose |
|-------|---------|---------|
| `app_name` | `app` | OTP app name; the template derives the test DB as `<app_name>_test` |
| `image_tag` | `v0.1.0` | `public-image-bases/elixir-builder` tag the jobs run on |

The `image_tag` input and the `ref` are both version pins: the template
version (`ref`) and the image version (`image_tag`) move independently and
explicitly.

## templates/go.yml

`lint` + `test` jobs for an Eiseron Go project. `lint` runs `eiseron go lint`
(gofmt, go vet, golangci-lint and the no-comments rule) on the `go-tools`
image, which ships those tools and the gem. `test` runs `go test ./... -race`.
Both cache the Go module and build caches keyed on `go.sum`.

```yaml
include:
  - project: eiseron/stack/ci
    file: /templates/go.yml
    ref: v0.1.0

stages:
  - lint
  - test
```

Inputs:

| input | default | purpose |
|-------|---------|---------|
| `go_image` | `golang:1.25` | image for the `test` job |
| `lint_image` | `public-image-bases/go-tools:v0.1.7` | image (go + golangci-lint + eiseron gem) for the `lint` job |

## templates/terraform-validate.yml

`terraform-validate` job — `init -backend=false` + `fmt -check -recursive` +
`validate` for an OpenTofu module, on the shared `iac` image
(which ships the `tofu` binary; its entrypoint is overridden so the shell
runs the script).

```yaml
include:
  - project: eiseron/stack/ci
    file: /templates/terraform-validate.yml
    ref: v0.1.20
    inputs:
      chdir: modules/preview_host

stages:
  - validate
```

Inputs:

| input | default | purpose |
|-------|---------|---------|
| `chdir` | `.` | directory of the OpenTofu module/config to validate |
| `image_tag` | `v0.1.16` | `public-image-bases/iac` tag the job runs on |
| `stage` | `validate` | pipeline stage for the job (the consumer must declare it) |

## templates/lock-smoke.yml

`lock-smoke` job — runs on **every MR** and on the default-branch push,
proving the `STACK_AUTOMATION_SHA` produced by the lock actually installs.
The prod-path templates (`prod-deploy`, `prod-backup`, `prod-restore`,
`db-backup-verify`) install the gem with
`gem specific_install <repo> -b "$STACK_AUTOMATION_SHA"` before running
anything — but those jobs are gated to production/schedule/web pipelines,
so an MR that bumps the stack/ci ref or the lock cannot exercise them.
`lock-smoke` runs the same install on the locked `$STACK_GEM_RUNTIME_IMAGE`
(every image goes through the manifest+lock; nothing hardcoded), and
`gem uninstall`s the baked gem first so the install path is actually
exercised — without the wipe, a stale baked binary would let the test
pass silently. It is the cheap CI-level guard against the divergence
class that broke `db restore` in handoff #72 — moved from one-shot manual
validation into a permanent precondition. Pairs with `ci check`, which
asserts the same locked SHA is what *every* baked image carries.

The job is wired transitively: `ops.yml` includes `lock-smoke.yml`, so every
consumer that includes `ops.yml`/`product-ops.yml`/`phoenix-ops.yml`/`org-ops.yml`
gets it automatically, with no opt-in needed.

```yaml
# wired automatically when you include any of the facade templates
include:
  - project: eiseron/stack/ci
    file: /templates/phoenix-ops.yml   # or product-ops / ops / org-ops
    ref: vX.Y.Z
    inputs: { ... }
stages: [lint, ...]   # lock-smoke runs in lint
```

Inputs: `stage` (default `lint`; the consumer must declare it).

Fails on:
- `STACK_AUTOMATION_REPO`/`STACK_AUTOMATION_SHA` missing (consumer is on a
  pre-lock ci ref);
- `gem specific_install -b "$STACK_AUTOMATION_SHA"` itself fails (the bug
  this template catches);
- `eiseron` binary not on `PATH` after install, or it does not start.

## templates/tofu-lint.yml

`tofu-lint` job — runs `eiseron tofu lint` (from the `automation` gem,
bundled in the `iac` image), which fails when any `.tf` file
contains a comment (`#`, `//`, or `/* */`). String literals are stripped and
heredoc bodies are skipped, so URLs, hex colors, and `#`/`//` inside embedded
scripts or policies are not flagged. Rationale belongs in the merge request
description, not in the source.

```yaml
include:
  - project: eiseron/stack/ci
    file: /templates/tofu-lint.yml
    ref: v0.1.20

stages:
  - lint
```

Inputs:

| input | default | purpose |
|-------|---------|---------|
| `chdir` | `.` | directory tree scanned for `.tf` files |
| `image_tag` | `v0.1.16` | `public-image-bases/iac` tag the job runs on |
| `stage` | `lint` | pipeline stage for the job (the consumer must declare it) |

## templates/terraform-drift.yml

`terraform-drift` job — drift alarm for Terraform repos whose secrets live
in SOPS-encrypted env files. Decrypts `secrets_file` with the `AGE_KEY`
variable of the target environment, runs
`terraform plan -detailed-exitcode -lock=false`, and fails when the plan is
not empty (exit code 2). Two triggers:

- scheduled pipelines carrying `DRIFT_CHECK=1` — catches drift born without
  any pipeline (manual UI edits, external mutations, stale copies);
- any default-branch pipeline except `trigger` ones — the same conditions
  under which apply jobs run (merge, manual web run, reconciliation
  schedules), so the alarm asserts convergence right after every apply.
  Place the job in a stage after apply (the `drift` stage by default; the
  consumer declares it last).

The `AGE_KEY` of the chosen `environment` must decrypt `secrets_file`. The
default is the readwrite file on purpose: resources that derive CI variables
for external consumers are fed by write-valued `var.*`, so a plan against
readonly substitutes would diff on them forever and the alarm would never be
green. Point `secrets_file`/`environment` at a readonly pair only if the
consumer repo has no such resources.

```yaml
include:
  - project: eiseron/stack/ci
    file: /templates/terraform-drift.yml
    ref: v0.1.19

stages:
  - plan
  - apply
  - drift
```

Inputs:

| input | default | purpose |
|-------|---------|---------|
| `chdir` | `.` | directory of the OpenTofu root module to check |
| `image_tag` | `v0.1.16` | `public-image-bases/iac` tag the job runs on |
| `stage` | `drift` | pipeline stage for the job (the consumer declares it after apply) |
| `secrets_file` | `secrets.readwrite.enc.env` | SOPS env file decrypted into the job environment |
| `environment` | `production` | environment whose protected variables (`AGE_KEY`) the job receives |

## templates/ansible-collection.yml

`ansible-collection` job — builds the Ansible collection, installs it, and
(optionally) `--syntax-check`s a playbook against it, on the shared
`python-ansible` image. An empty `playbook` input skips the syntax-check.

```yaml
include:
  - project: eiseron/stack/ci
    file: /templates/ansible-collection.yml
    ref: v0.1.3
    inputs:
      playbook: playbooks/preview-host.yml

stages:
  - validate
```

Inputs:

| input | default | purpose |
|-------|---------|---------|
| `playbook` | _(empty)_ | playbook to `--syntax-check` after install; empty skips it |
| `image_tag` | `v0.1.3` | `public-image-bases/python-ansible` tag the job runs on |
| `stage` | `validate` | pipeline stage for the job (the consumer must declare it) |

## templates/preview-app.yml

App-side preview template — builds the per-MR / main image and triggers
the ops repo to deploy/stop it. Replaces the legacy `preview-build.yml`.

Four jobs:

- `build_image` — kaniko build of `dockerfile_path`, pushes
  `$CI_REGISTRY_IMAGE/preview:<slug>` and `<slug>-sha-<short>`. Auth via
  the `<app>_preview_registry` deploy token (`PREVIEW_REGISTRY_USER` /
  `PREVIEW_REGISTRY_PASSWORD`, provisioned by the consumer's terraform).
- `deploy_preview` — MR-only. `environment: preview/<slug>`, URL
  `https://<slug>-$PREVIEW_DOMAIN_BASE`, with `on_stop: stop_preview` and
  `auto_stop_in`. Calls `eiseron preview trigger` to fan out to the ops
  pipeline (`PREVIEW_KIND=mr`).
- `deploy_main` — default-branch only. `environment:
  <main_environment_name>`, URL
  `https://<main_environment_name>-$PREVIEW_DOMAIN_BASE`. Same trigger
  path with `PREVIEW_KIND=main`.
- `stop_preview` — MR-only, manual. `environment.action: stop`. Triggers
  the ops pipeline with `PREVIEW_ACTION=stop`.

Trigger jobs run on `$STACK_GEM_RUNTIME_IMAGE` (eiseron CLI baked at
`$STACK_AUTOMATION_SHA`); no in-job gem install. The POST to the
deployer's trigger token bypasses ref-protection on the ops main branch,
which is required because GitLab bridges fail with
`insufficient_bridge_permissions` against "no-one"-protected refs.

```yaml
# in the product's APP repo
include:
  - project: eiseron/stack/ci
    file: /templates/preview-app.yml
    ref: vX.Y.Z
    inputs:
      app_name: example
      mix_env: preview

stages:
  - build
  - preview
```

Inputs (all but `app_name` have sensible defaults):

| input | default | purpose |
|-------|---------|---------|
| `app_name` | _(required)_ | product slug; per-MR/main image basename and traefik label namespace |
| `build_stage` | `build` | pipeline stage for `build_image` |
| `preview_stage` | `preview` | pipeline stage for the three trigger jobs |
| `dockerfile_path` | `.docker/Dockerfile.preview` | dockerfile baked by kaniko |
| `assets_command` | `mix assets.deploy` | asset build before image build |
| `mix_env` | `staging` | MIX_ENV the image compiles with |
| `builder_image` | `…/elixir-builder:latest` | elixir-tools + kaniko, one job for compile + push |
| `main_environment_name` | `main` | environment name `deploy_main` binds to; same value lands in `<…>-$PREVIEW_DOMAIN_BASE` URL |
| `preview_auto_stop_in` | `7 days` | GitLab auto-stop idle window (stop is dispatched manually before this in practice) |

CI vars expected (all provisioned by `stack/provisioning`'s
`module.product` once the consumer wires `preview_host_ip`):
`PREVIEW_DOMAIN_BASE`, `PREVIEW_REGISTRY_USER` /
`PREVIEW_REGISTRY_PASSWORD`, `PREVIEW_DEPLOYER_PROJECT` /
`PREVIEW_DEPLOYER_TRIGGER_TOKEN`. The bootstrap-guard rules skip jobs
silently while these are still empty.

## templates/preview-dispatch.yml

Ops-side preview template — single `preview` job that runs
`eiseron preview dispatch`, which routes on `PREVIEW_ACTION` to the
`Preview::Deploy` / `Preview::Stop` / `Preview::Sweep` Ruby classes in
`stack/automation`. Replaces the legacy `preview-deploy.yml` +
`preview-sweep.yml` pair and the intermediate bash deployer scripts.

The actions:

- `deploy` — full per-MR / per-main deploy (docker auth on host, image
  pull, stop previous, ensure shared roles, recreate per-MR roles + DB,
  one-shot migrate as admin role, render compose template + bring up,
  CF-Access-protected `/healthz` healthcheck, registry tag release).
- `stop` — force teardown of one MR ref (compose down -v --rmi all,
  drop DB + roles, delete registry tag).
- `sweep` — reconciler (`docker compose ls --filter name=mr-`, read MR
  state per project, tear down anything not `opened`). The `mr-`
  filter is the structural guarantee that the `main` compose project
  is immune to sweep mistakes.

`stop` and `sweep` are distinct on purpose: sweep is the reconciler
(skips MRs still open), stop is the imperative per-ref teardown (runs
regardless). Conflating them prevents `on_stop` from working while a
review MR is still open.

Scheduled pipelines without an explicit `PREVIEW_ACTION` (and without
`DRIFT_CHECK=1`) default to `sweep`. `environment: production` is fixed
— it scopes the production CI vars (`SHARED_PG_USER`, `VPS_USER`,
`PREVIEW_HOST_IP`, `ANSIBLE_SSH_PRIVATE_KEY`, `GITLAB_API_TOKEN`,
`PREVIEW_*`, `EISERON_PREVIEW_*`) to the dispatcher job.

Job runs on `$STACK_GEM_RUNTIME_IMAGE`, which ships the eiseron gem
pinned to `$STACK_AUTOMATION_SHA` plus the tools the gem shells out
to (ssh, docker CLI, curl, postgres-client). No `before_script`
required.

```yaml
# in the product's OPS repo
include:
  - project: eiseron/stack/ci
    file: /templates/preview-dispatch.yml
    ref: vX.Y.Z

stages:
  - preview
```

Inputs (both have defaults):

| input | default | purpose |
|-------|---------|---------|
| `preview_stage` | `preview` | pipeline stage for the dispatcher |
| `preview_timeout` | `5 minutes` | max wall-clock per dispatch invocation |

The consumer ops repo supplies the compose template (path via
`EISERON_PREVIEW_COMPOSE_TEMPLATE`) and the production-scoped CI vars
the gem reads — `EISERON_PREVIEW_APP_NAME`, `PREVIEW_PROJECT_PATH`,
`VPS_USER`, `PREVIEW_HOST_IP`, `ANSIBLE_SSH_PRIVATE_KEY` (file-type),
`SHARED_PG_USER`, `PREVIEW_IMAGE_PULL_USER` / `_TOKEN`,
`PREVIEW_SECRET_KEY_BASE`, `PREVIEW_HEALTHCHECK_TOKEN_ID` / `_SECRET`,
`GITLAB_API_TOKEN`. See `stack/automation`'s README for the full
contract.

`templates/preview-build.yml` is the last remnant of the previous
preview model and stays available until afinados (its last consumer)
finishes migrating to `preview-app.yml`. Don't add new consumers to it.

## templates/release.yml

`release-tag` job — the **only** way a stack repo gets a tag. Tags are
protected at "no one" (Terraform-managed in `eiseron-ops`), so no human,
maintainer, or push can create them. The tagging logic lives in the
`eiseron_automation` gem (`eiseron/stack/automation`), which this job
installs from a pinned git tag and invokes as `eiseron release tag`. When
the version file changes on a protected ref (`main` or `release/*`), the
command reads `v<version>`, lifts tag protection with the protected
`EISERON_STACK_TOKEN`, creates the tag from the reviewed commit, and
restores protection. A tag therefore always maps to a reviewed MR that
bumped the version.

```yaml
include:
  - project: eiseron/stack/ci
    file: /templates/release.yml
    ref: v0.1.2

stages:
  - release
```

Add a `VERSION` file at the repo root holding the bare semver (no `v`):

```
0.1.0
```

Bump it in an MR; on merge the job tags `v0.1.0`. Re-runs are idempotent
(skips if the tag exists). Maintenance releases: branch `release/X.Y` off
the old tag, bump `VERSION`, MR into the protected release branch.

Inputs:

| input | default | purpose |
|-------|---------|---------|
| `version_file` | `VERSION` | path to the bare-semver file the job reads |
| `automation_ref` | `v0.1.1` | tag of `eiseron/stack/automation` (the `eiseron_automation` gem) to install |
| `image` | `ruby:3.3-alpine` | Ruby image used to install and run the `eiseron` CLI |

## templates/sync-github.yml

`sync-github` job — mirrors `main` + tags to `github.com/eiseron/<project>`
(needs a `GITHUB_TOKEN` CI variable). Include it in projects that mirror:

```yaml
include:
  - project: eiseron/stack/ci
    file: /templates/sync-github.yml
    ref: v0.1.0

stages:
  - sync
```

## templates/publish-docs.yml

`publish-docs` job — on a semver tag, installs the `eiseron_automation` gem
and runs `eiseron docs publish`: clones the docs site, refreshes the latest
docs (preserving frozen version snapshots), freezes a `v<MAJOR.MINOR>`
snapshot, updates `versions.json` and pushes to the site. The product
authors docs in its own repo; a tag ships them. Needs a `GITLAB_TOKEN` CI
variable with write access to the site (declare it via Terraform).

```yaml
include:
  - project: eiseron/stack/ci
    file: /templates/publish-docs.yml
    ref: v0.1.10
    inputs:
      site_repo: eiseron/group/site
      locale_map: '{"pt_BR":"src/docs","en":"src/en/docs"}'

stages:
  - publish
```

Inputs:

| input | default | purpose |
|-------|---------|---------|
| `site_repo` | _(required)_ | full path of the docs site repo |
| `locale_map` | _(required)_ | JSON object mapping source locale dir to site dest dir |
| `automation_ref` | `v0.4.0` | `eiseron/stack/automation` tag (the `eiseron` CLI) |
| `image` | `ruby:3.3-alpine` | Ruby image to install and run the CLI |
| `source_dir` | `docs` | dir in the product repo holding the locale doc dirs |
| `versions_file` | `versions.json` | versions manifest path in the site repo |
| `site_branch` | `main` | branch of the site repo to push to |
| `stage` | `publish` | pipeline stage (the consumer must declare it) |

## templates/prod-platform.yml

Platform bootstrap for the shared production host, run from `eiseron-ops`.
Clones the public `provisioning` at `provisioning_ref`, renders the canonical
`kamal/platform` manifest from env, and boots the shared services with
`kamal accessory boot db` (shared postgres on the encrypted root) and
`kamal proxy boot` (kamal-proxy, the shared proxy every product registers
with). Per-product DB + login roles are created separately (`eiseron prod
tenant`), between this and the product deploys. Web-manual only.

```yaml
# in eiseron-ops
include:
  - project: eiseron/stack/ci
    file: /templates/prod-platform.yml
    ref: vX.Y.Z
stages: [platform]
```

CI vars the consumer provides (Terraform-managed in `eiseron-ops`):

| var | purpose |
| --- | --- |
| `PROD_SSH_PRIVATE_KEY` | File var: OpenSSH private key for the prod host |
| `PROD_HOST` | prod host IP/name (manifest) |
| `POSTGRES_PASSWORD` | shared postgres superuser password |
| `KAMAL_REGISTRY_USERNAME` / `KAMAL_REGISTRY_PASSWORD` | registry creds |

Optional (manifest defaults): `PG_ADMIN_USER`, `KAMAL_REGISTRY_SERVER`, `DEPLOY_SSH_USER`, `PLATFORM_NOOP_IMAGE`.

## templates/prod-deploy.yml

App-only product deploy, triggered by the product's `prod-build` pipeline
(`PROD_TAG` / `PROD_PROJECT` / `PROD_ACTION=deploy`). Clones the public
`provisioning` at `provisioning_ref`, renders the canonical `kamal/app`
manifest from env, and runs `eiseron prod deploy` (kamal deploy of the
pre-built image, anti-downgrade guard). The app registers with the shared
kamal-proxy and connects to the platform's shared postgres. `eiseron prod
deploy` idempotently re-applies the managed `PROD_TENANT_PASSWORD` to the role
(a no-op on a normal deploy) and assembles `DATABASE_URL` into the kamal
subprocess only, so the URL is never a CI var, log line, or state entry.

```yaml
# in <product>-ops
include:
  - project: eiseron/stack/ci
    file: /templates/prod-deploy.yml
    ref: vX.Y.Z
    inputs:
      app_service: app
      app_image: org/group/app/prod
      app_host: app.example.com
      app_release_module: App
      tenant_slug: app
stages: [deploy]
```

Per-product, non-secret descriptors are committed as template inputs (auditable
MR, not a mutable CI var): `app_service`, `app_image`, `app_host`,
`app_release_module`, `tenant_slug`, `app_port` (default `4000`), `db_url_scheme`
(default `ecto`).

CI vars the consumer provides (Terraform-managed in `<product>-ops`):

| var | purpose |
| --- | --- |
| `PROD_SSH_PRIVATE_KEY` | File var: OpenSSH private key for the prod host |
| `PROD_DEPLOY_READ_TOKEN` | read_api token on the product repo (latest-tag guard) |
| `PROD_PROJECT` | product repo path (latest-tag guard) |
| `PROD_HOST` | prod host IP/name (manifest + password apply) |
| `KAMAL_REGISTRY_USERNAME` / `KAMAL_REGISTRY_PASSWORD` | registry creds |
| `SECRET_KEY_BASE` | app session secret |
| `PROD_TENANT_PASSWORD` | managed DB role password (`random_password` + keeper); re-applied each deploy, rotated by bumping the keeper |

Optional (manifest defaults): `PROXY_SSL`, `KAMAL_REGISTRY_SERVER`, `DEPLOY_SSH_USER`.

## templates/prod-tenant.yml

Per-product Postgres provisioning on the shared host, run from `<product>-ops`
once between `prod-platform` and the first deploy. Runs `eiseron prod tenant`,
which creates the role and database (`<tenant_slug>` / `<tenant_slug>_prod`) over
SSH (`psql` against the platform admin), seeding the role with the managed
`PROD_TENANT_PASSWORD`. It does not clone the manifest. Web-manual only.

```yaml
# in <product>-ops
include:
  - project: eiseron/stack/ci
    file: /templates/prod-tenant.yml
    ref: vX.Y.Z
    inputs:
      tenant_slug: app
stages: [tenant]
```

CI vars the consumer provides (Terraform-managed in `<product>-ops`):

| var | purpose |
| --- | --- |
| `PROD_SSH_PRIVATE_KEY` | File var: OpenSSH private key for the prod host |
| `PROD_HOST` | prod host IP/name |
| `PROD_TENANT_PASSWORD` | managed DB role password the role is seeded with |

Optional (`psql`-over-SSH defaults): `PG_CONTAINER` (`platform-db`), `PG_ADMIN_USER` (`eiseron`), `DEPLOY_SSH_USER` (`deploy`).

## templates/db-restore-drill.yml

Scheduled `db-restore-drill` job — the mandatory gate that proves the latest
encrypted backup is restorable. On the `gem-runtime` image it runs `eiseron
db restore-drill`, which pulls the newest `*.sql.age` object from the backups
bucket, decrypts it with the low-privilege **drill** key (never the cold DR
key), restores it into a throwaway Postgres service, and verifies the result.
A failure fails the scheduled pipeline (the alert); the cold DR key stays
offline. Runs in the product's ops repo on a schedule (production scope, so
the drill key and R2 read creds are available).

```yaml
# in the product's OPS repo, on a schedule
include:
  - project: eiseron/stack/ci
    file: /templates/db-restore-drill.yml
    ref: v0.1.42
    inputs:
      app_name: example

stages:
  - drill
```

Inputs:

| input | default | purpose |
|-------|---------|---------|
| `app_name` | `app` | product slug; selects the backup object prefix (`PROD_BACKUP_NAME`) |
| `image_tag` | `v0.1.19` | `public-image-bases/gem-runtime` tag (eiseron CLI + age + pg client + aws-sdk) |
| `pg_image` | `postgres:18` | throwaway Postgres the drill restores into (match the prod server major) |
| `drill_stage` | `drill` | pipeline stage (the consumer must declare it) |

The ops repo supplies (production scope): `PROD_BACKUP_BUCKET`,
`CLOUDFLARE_ACCOUNT_ID`, `PROD_BACKUP_DRILL_KEY`, `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY` (R2 read).

The job runs only when the firing pipeline carries `BACKUP_JOB=drill` — set
the variable on the drill schedule (`gitlab_pipeline_schedule_variable`) or
type it into a manual web run. Without it the drill is silent, which is what
lets the daily `db-backup-verify` schedule live next to the weekly drill
schedule without each one triggering the other.

## templates/prod-backup.yml

Manual "backup now" job — an on-demand snapshot outside the daily cron, for
verifying the pipe end to end or capturing a point before a risky change. On
the ops image it runs `eiseron prod backup`, which `kamal accessory exec`s a
one-shot `eiseron db backup` inside the already-running backup accessory: an
ephemeral container with the accessory's env, network and `/backups` volume,
so the backup runs fully configured without touching the running scheduler and
without host access. The dump is `pg_dump | age`d to the recipients and
uploaded to R2 (and the run self-prunes old objects, like the scheduled one).

Gated to the **production branch**, `when: manual` — run a pipeline on
`production` and click `prod-backup`. (Unlike `prod-restore` it needs no extra
variable: a backup is non-destructive.)

```yaml
# in <product>-ops (included via product-ops/phoenix-ops)
include:
  - project: eiseron/stack/ci
    file: /templates/prod-backup.yml
    ref: vX.Y.Z
    inputs:
      app_service: app
stages: [backup]
```

Inputs: `app_service` (the accessory is `<app_service>-backup`), `automation_ref`
(carries `eiseron prod backup`), `image_tag` (ops), `backup_stage` (default
`backup`). Reuses the accessory's production-scope CI vars (PG/AWS/recipients);
no new var to pass.

## templates/prod-restore.yml

Manual restore job — the destructive DR action (distinct from the weekly
`db-restore-drill`, which only *tests* restorability in a throwaway DB). On the
ops image it runs `eiseron prod restore`, which pipes the **drill private key
over `ssh → docker exec -i`** into the running backup accessory (the key is on
stdin only — never in argv, `docker inspect`, disk, or shell history; no
decryption key is added to the always-on sidecar). Inside, `eiseron db restore`
**snapshots the current database first** (so the overwrite is reversible),
decrypts the chosen object with the drill key (`age -i -`), `DROP SCHEMA public
CASCADE; CREATE SCHEMA` as the database owner (in place — no `CREATEDB`, no
re-owning), loads the dump, and verifies. The drill key alone decrypts any
backup (multi-recipient age); the offline cold DR key is never needed for a
routine restore.

Gated to the **production branch**, `when: manual`, and the rule requires
**both** run variables, so the button only appears when armed:

| run variable | answers | role |
|--------------|---------|------|
| `PROD_RESTORE_KEY` | *which* backup (`<prefix>/<stamp>.sql.age`, or `latest`) | functional — what to restore |
| `PROD_RESTORE_CONFIRM` | *are you sure* you will overwrite the live DB | safety — must equal the database name (`<slug>_prod`), the type-the-name-to-confirm guard; the gem refuses otherwise |

To restore: run a pipeline on `production` with both variables set, then click
`prod-restore`. If it was the wrong choice, restore again from the pre-restore
snapshot the job took.

```yaml
# in <product>-ops (included via product-ops/phoenix-ops)
include:
  - project: eiseron/stack/ci
    file: /templates/prod-restore.yml
    ref: vX.Y.Z
    inputs:
      app_service: app
stages: [restore]
```

Inputs: `app_service`, `automation_ref` (carries `eiseron prod restore`),
`image_tag` (ops), `restore_stage` (default `restore`). Reuses the accessory's
production-scope env; the drill key reaches the host only over stdin.

## templates/db-backup-verify.yml

Scheduled staleness alarm — daily auditor that catches the case the
`db-restore-drill` cannot: backups *stopped happening*. The drill proves an
existing backup restores; the verifier proves a *new* backup landed. It runs
`eiseron db backup verify`, which lists the product prefix in R2, picks the
newest `.sql.age` object, parses the ISO-8601 stamp from its key, and fails if
the gap to `now` exceeds `PROD_BACKUP_STALE_HOURS` (default 30). Empty prefix
or unparseable name also fail. Pipeline failure → GitLab notification to the
assignees — the alert channel until proper observability lands.

Designed **decoupled from the scheduler**: read-only on R2, never touches the
database or the accessory, runs in CI on its own schedule. If the accessory
crashes (backups stop), the verifier still alerts; if it ran inside the
accessory, a broken backup would silence its own alarm. The gem is reinstalled
fresh from `automation_ref` at job start (`gem specific_install`), so the
verify command is never trapped behind a stale baked image.

```yaml
# in the product's OPS repo, on a daily schedule
include:
  - project: eiseron/stack/ci
    file: /templates/db-backup-verify.yml
    ref: vX.Y.Z
    inputs:
      app_name: example
stages: [verify]
```

The ops repo supplies (production scope, R2 read): `PROD_BACKUP_BUCKET`,
`CLOUDFLARE_ACCOUNT_ID`, `PROD_DRILL_AWS_ACCESS_KEY_ID`,
`PROD_DRILL_AWS_SECRET_ACCESS_KEY` (mapped to `AWS_*` by the template).
Optional: `PROD_BACKUP_STALE_HOURS` (override the 30 default).

Inputs: `app_name`, `automation_ref` (carries `eiseron db backup verify`),
`image_tag` (`gem-runtime`), `verify_stage` (default `verify`).

The job runs only when the firing pipeline carries `BACKUP_JOB=verify` — set
the variable on the verify schedule (`gitlab_pipeline_schedule_variable`) or
type it into a manual web run. The discriminator keeps the verify schedule
from also triggering the weekly drill, and vice versa.

## templates/notify-telegram.yml

Reusable `after_script` snippet that routes a job failure to a Telegram bot,
on top of the GitLab assignee email that already exists. Defines the hidden
job `.notify_telegram_on_failure`; consumers `extends:` it. Runs in
`after_script` (not `script`) so a Telegram outage cannot mask the real job
error. Gates on `CI_JOB_STATUS == failed` (after_script always runs); on
absent `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID` (MR pipelines lack protected
vars); posts to `api.telegram.org` via **raw `curl`** with `--data-urlencode`.

`curl` instead of the gem on purpose: an alert that depends on the locked
`STACK_AUTOMATION_SHA` would force every alert-adding feature to also push a
new baked image (the lock-check rejects any drift). Keeping the after_script
independent of automation versioning means the template ships once and
survives every `eiseron ci update`.

```yaml
# in another template
include:
  - local: /templates/notify-telegram.yml

my-job:
  extends: .notify_telegram_on_failure
  script:
    - …
```

No inputs; no variables. The consuming ops repo must provide
`TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` as protected production CI
variables (gated `gitlab_project_variable` on sops in the repo, like
`PROD_BACKUP_DRILL_KEY`).

Extended by `db-backup-verify.yml` (stale backup) and `terraform-drift.yml`
(missed apply). **Not** extended by `ancestry-check.yml`: that template runs
on every merge request and would flood the channel with PR-time errors that
already show up in the review UI.

## templates/workers.yml

CI for a stack repo that ships pure-JS Cloudflare Worker scripts (e.g.
`eiseron/stack/workers`). One `lint` job (`node --check` over every `*.js`
in the configured directory) and the standard `release.yml` chain so a
VERSION bump on the default branch publishes `vX.Y.Z`.

Inputs:

- `workers_dir` (default `workers`): the directory holding the worker
  source files the lint job scans.

The Node image is locked centrally via `STACK_NODE_IMAGE` (`manifest.yml`
+ `lock.yml`); consumers pick it up automatically. Why so spartan: workers in this stack are deliberately small (one file per
worker, no build step, no framework, no TypeScript). The CI matches that
shape — anything beyond syntax-checking would push the source toward a
heavier code style than the repo wants.

```yaml
# in eiseron/stack/workers/.gitlab-ci.yml
include:
  - project: eiseron/stack/ci
    file: /templates/workers.yml
    ref: v0.4.0

stages:
  - lint
  - release
```

Consumers of an individual worker script (the `cloudflare_workers_script`
resource in `stack/provisioning`) pin a `ref` of `stack/workers` themselves;
the lint template does not gate that.
