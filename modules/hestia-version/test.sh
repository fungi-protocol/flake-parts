#!/usr/bin/env bash
# Exercise action selection and pin-comment parsing with the check's yq.
set -euo pipefail
helper=$1
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

failures=0
check() {
  local name=$1 expected=$2 action=$3 comment=$4 version=$5 status=0
  cat >"$work/$name.yml" <<EOF
jobs:
  check:
    steps:
      - uses: $action@dfed9ced335d28978ba74e513939a10db1f71025 #$comment
        with:
          version: $version
EOF
  bash "$helper" "$work/$name.yml" >"$work/$name.log" 2>&1 || status=$?
  if [[ $status != "$expected" ]]; then
    cat "$work/$name.log" >&2
    echo "$name: expected exit $expected, got $status" >&2
    failures=1
  fi
}

check matching 0 Mic92/hestia ' v3.1.0' v3.1.0
check lowercase-mismatch 1 mic92/hestia ' v3.1.0' v3.0.1
check mixed-case-mismatch 1 MIC92/Hestia ' v3.1.0' v3.0.1
check unpinned-latest 1 Mic92/hestia ' latest' latest
check compact-comment 0 Mic92/hestia v3.1.0 v3.1.0
check annotated-comment 0 Mic92/hestia '   v3.1.0 release pin   ' v3.1.0
check pipe-annotation 0 Mic92/hestia ' v3.1.0 | release notes' v3.1.0
check pipe-annotation-mismatch 1 Mic92/hestia ' v3.1.0 | release notes' v3.0.1
check prerelease 0 Mic92/hestia ' v3.1.0-rc.1+build.2' v3.1.0-rc.1+build.2
check unrelated-action 0 someone/hestia ' latest' latest

cat >"$work/flow.yml" <<'EOF'
jobs:
  check:
    steps:
      - {uses: 'Mic92/hestia@dfed9ced335d28978ba74e513939a10db1f71025', with: {version: v3.1.0}} # v3.1.0
EOF
bash "$helper" "$work/flow.yml" || failures=1

exit "$failures"
