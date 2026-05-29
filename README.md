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
