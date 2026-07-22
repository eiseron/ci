#!/bin/sh
set -eu

template="templates/db-backup-run.yml"

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

want "db-backup-run:" "run job is missing"
want '$STACK_K8S_IMAGE' "kubectl image must come from the lock (STACK_K8S_IMAGE, alpine/k8s -- bitnami/kubectl has no numbered tags at all, so it can never resolve through manifest.yml's semver-based lock)"
want "/lock.yml" "must include lock.yml, which defines STACK_K8S_IMAGE"
want "kubectl create job" "job must clone the CronJob via kubectl create job"
want '--from="cronjob/$[[ inputs.app_name ]]-db-backup"' "job must clone the product's own CronJob, not a hardcoded name"
want "name: production" "environment must be production so the cluster credentials resolve"
want "GIT_STRATEGY: none" "run needs no source checkout"

want '$TF_VAR_cluster_host' "job must authenticate with the same cluster credentials Terraform already uses"
want '$TF_VAR_cluster_token' "job must authenticate with the same cluster credentials Terraform already uses"
want '$TF_VAR_cluster_ca_cert' "job must authenticate with the same cluster credentials Terraform already uses"

want 'if: $CI_COMMIT_BRANCH == "production"' "run must only be offered on the production branch"
want "when: manual" "run must never fire on its own; it is a manual on-demand trigger only"
want "resource_group: production" "run must serialize against other production-environment jobs (e.g. a concurrent apply)"
absent 'CI_PIPELINE_SOURCE == "schedule"' "run must never fire on its own schedule; it is a manual on-demand trigger only"
absent 'merge_request_event' "run must not run on merge requests"

want "extends: .notify_telegram_on_failure" "run must extend the Telegram on-failure snippet so a failed manual backup alerts beyond the assignee email"
want "/templates/notify-telegram.yml" "run must include the notify-telegram template that defines the extends target"

echo "PASS: db-backup-run template wiring (manual, production-only, clones the product's own CronJob)"
