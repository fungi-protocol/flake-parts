#!/usr/bin/env bash

# Usage: hestia-version.sh WORKFLOW...
#
# Fails unless every Mic92/hestia step sets `version` to the release named in
# its pin comment.

set -euo pipefail

steps=$(mktemp)
trap 'rm -f "$steps"' EXIT
status=0
for workflow in "$@"; do
  # Capture yq's exit status and keep arbitrary comment text in one field.
  # shellcheck disable=SC2016 # $pin is a yq variable.
  if ! yq -0r '..
      | select(tag == "!!map" and has("uses"))
      | select(.uses | test("(?i)^mic92/hestia@"))
      | (.uses | line_comment) as $pin
      | [.uses, (($pin | select(. != "")) // (select(style == "flow") | line_comment) // ""), (.with.version // "")]
      | .[]' "$workflow" >"$steps"; then
    echo "$workflow: cannot parse workflow" >&2
    status=1
    continue
  fi
  while IFS= read -rd '' uses && IFS= read -rd '' pin && IFS= read -rd '' version; do
    # yq retains '#' for compact comments; the first word names the release.
    read -r pin _ <<<"${pin#\#}"
    release='^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
    if [[ ! $pin =~ $release || $version != "$pin" ]]; then
      echo "$workflow: $uses pins '${pin:-no release comment}' but sets version '${version:-latest}'" >&2
      status=1
    fi
  done <"$steps"
done

exit "$status"
