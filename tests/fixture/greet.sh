#!/usr/bin/env bash
set -euo pipefail

name=${1:-world}
if [[ -n $name ]]; then
  echo "hello, $name"
fi
