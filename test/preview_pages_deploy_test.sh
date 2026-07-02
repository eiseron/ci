#!/bin/sh
set -eu

template="templates/preview-pages-deploy.yml"

fail() {
  echo "FAIL: $1"
  exit 1
}

want() {
  grep -qF -- "$1" "$template" || fail "$2"
}

reject() {
  grep -qF -- "$1" "$template" && fail "$2" || true
}

want "preview_pages:" "preview_pages job is missing"

want "eiseron preview dispatch" "does not delegate to the eiseron CLI"
want "name: production" "deployer job does not bind environment: production (needed for the protected token)"
want 'CLOUDFLARE_API_TOKEN: "$CLOUDFLARE_PAGES_PREVIEW_TOKEN"' "deployer does not wire the protected preview token"

want 'if: $PREVIEW_KIND != "pages"' "deployer is not gated to the pages kind"
want '$PREVIEW_ACTION == "deploy"' "deployer does not handle deploy"
want '$PREVIEW_ACTION == "stop"' "deployer does not handle stop"

want "STACK_GEM_RUNTIME_IMAGE" "deployer does not run on the gem-runtime image"
want "nodejs" "deployer does not install Node for wrangler"

reject "PREVIEW_PAGES_PROJECT:" "the deploy target must come from the deployer's own protected var, not be set in the template"
