#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
case "${1:---staged}" in
  --staged) gitleaks git --staged --redact --no-banner . ;;
  --history) gitleaks git --log-opts='--all' --redact --no-banner . ;;
  *) echo 'Usage: check-secrets.sh [--staged|--history]' >&2; exit 2 ;;
esac
python3 scripts/check-sops.py --index
