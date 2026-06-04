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

## templates/terraform-validate.yml

`terraform-validate` job — `init -backend=false` + `fmt -check -recursive` +
`validate` for a Terraform module, on the shared `terraform-tools` image
(whose `terraform` entrypoint is overridden so the shell runs the script).

```yaml
include:
  - project: eiseron/stack/ci
    file: /templates/terraform-validate.yml
    ref: v0.1.3
    inputs:
      chdir: modules/preview_host

stages:
  - validate
```

Inputs:

| input | default | purpose |
|-------|---------|---------|
| `chdir` | `.` | directory of the Terraform module/config to validate |
| `image_tag` | `v0.1.3` | `public-image-bases/terraform-tools` tag the job runs on |
| `stage` | `validate` | pipeline stage for the job (the consumer must declare it) |

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

## templates/preview-deploy.yml

`preview-deploy` and `preview-stop` jobs that run the
`eiseron.provisioning.preview_app` playbook (installed from a pinned
collection tag) over SSH to the shared preview host.

The host credentials (`PREVIEW_HOST_IP`, `PREVIEW_ANSIBLE_SSH_PRIVATE_KEY`)
must never reach the app repo, so this template is **included by the
product's ops repo**, not the app repo. The app repo's MR pipeline builds
and pushes its image (registry creds only), then **triggers** the ops repo
passing `PREVIEW_MR_IID`, `PREVIEW_ACTION` (`deploy`/`stop`), and
`PREVIEW_APP_IMAGE`. The triggered ops pipeline runs on a protected ref, so
the protected host creds are in scope. Each job assembles `DATABASE_URL`
from `PREVIEW_TENANT_NAME` / `PREVIEW_TENANT_PASSWORD` and the per-MR
database, merges `PREVIEW_APP_EXTRA_ENV` (a JSON object of product secrets
like `SECRET_KEY_BASE`), and serves the app at
`<app_name>-mr-<iid><preview_suffix>.<preview_zone>`. Jobs are serialized
per MR via `resource_group`. Teardown of merged/closed MRs is the ops
repo's responsibility (a scheduled sweep that triggers `stop`).

```yaml
# in the product's OPS repo
include:
  - project: eiseron/stack/ci
    file: /templates/preview-deploy.yml
    ref: v0.1.6
    inputs:
      app_name: example
      preview_zone: example.com
      preview_suffix: "-preview"
      db_url_scheme: ecto

stages:
  - deploy
```

Inputs:

| input | default | purpose |
|-------|---------|---------|
| `preview_zone` | _(required)_ | DNS zone; app served at `<app_name>-mr-<iid><preview_suffix>.<preview_zone>`, must be covered by the host wildcard cert |
| `app_name` | `app` | product slug; deploy named `<app_name>-mr-<iid><preview_suffix>` |
| `preview_suffix` | _(empty)_ | suffix before the zone, e.g. `-preview` to serve `<slug>-preview.<zone>` |
| `app_port` | `4000` | container port the app listens on |
| `db_host` / `db_port` | `shared-pg` / `5432` | shared Postgres address on the host docker network |
| `db_url_scheme` | `postgresql` | scheme for the assembled `DATABASE_URL` (e.g. `ecto`) |
| `provisioning_ref` | `v0.8.0` | `eiseron.provisioning` collection tag to install and run |
| `image_tag` | `v0.1.3` | `public-image-bases/python-ansible` tag the jobs run on |
| `deploy_stage` / `stop_stage` | `deploy` | pipeline stages (the consumer must declare them) |

The ops repo supplies (Terraform-managed in `eiseron-ops`, protected):
`PREVIEW_HOST_IP`, `PREVIEW_ANSIBLE_SSH_PRIVATE_KEY`, `PREVIEW_TENANT_NAME`,
`PREVIEW_TENANT_PASSWORD`, and `PREVIEW_APP_EXTRA_ENV`. The trigger supplies
`PREVIEW_MR_IID`, `PREVIEW_ACTION`, and `PREVIEW_APP_IMAGE`.

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
