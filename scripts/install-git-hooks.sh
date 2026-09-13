#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
previous=$(git config --get core.hooksPath || true)
if [[ -n "$previous" && "$previous" != .githooks ]]; then
  echo "Existing core.hooksPath=$previous; integrate the existing hooks before installing." >&2
  exit 1
fi
if [[ -z "$previous" && -f "$(git rev-parse --git-path hooks/pre-commit)" ]]; then
  echo 'Existing pre-commit hook found; integrate it before installing.' >&2
  exit 1
fi
git config --local core.hooksPath .githooks
echo 'Repository pre-commit checks enabled.'
