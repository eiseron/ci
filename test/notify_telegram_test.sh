#!/bin/sh
set -eu

template="templates/notify-telegram.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

want ".notify_telegram_on_failure:" "hidden job .notify_telegram_on_failure is missing (consumers extend it)"
want "after_script:" "snippet must run in after_script (not script) so it cannot mask the original job error"
want 'CI_JOB_STATUS' "snippet must gate on CI_JOB_STATUS so it only runs on failure"
want 'TELEGRAM_BOT_TOKEN' "snippet must short-circuit when the bot token is absent (MR pipelines, unconfigured products)"
want 'TELEGRAM_CHAT_ID' "snippet must short-circuit when the chat id is absent"
want 'api.telegram.org' "snippet must call Telegram's sendMessage endpoint directly (curl, no gem dependency, so it survives any baked-image automation_ref)"
want '/sendMessage' "snippet must POST to sendMessage"
want 'data-urlencode' "snippet must URL-encode the payload (otherwise project paths with /, refs with @, and multi-line text break the POST body)"
want '--max-time' "snippet must time-bound the curl call so a hung Telegram doesn't pad the job runtime"

grep -qF 'gem specific_install' "$template" &&
  fail "snippet must not install the gem — coupling to STACK_AUTOMATION_SHA reintroduces the baked-vs-lock divergence and forces a public-image-bases rebuild on every feature that adds an alert. Raw curl keeps the template independent of automation versioning"

grep -qF 'command -v eiseron' "$template" &&
  fail "snippet must not call eiseron (kept curl-only after the lock-vs-baked tension showed gem dependency is too heavy for an after_script alert)"

grep -qE '^notify_telegram_on_failure:' "$template" &&
  fail "snippet must stay hidden (.notify_telegram_on_failure); without the leading dot GitLab would schedule it as a real job on every pipeline"

echo "PASS: notify-telegram template wiring (hidden job, after_script gated on failure, raw curl — independent of automation/baked image)"
