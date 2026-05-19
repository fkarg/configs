#!/bin/sh
# Pre-cutover sanity check for the ansible layout. Runs from the repo root.
#
# Verifies:
#   1. All entry playbooks parse cleanly
#   2. site.yml --check against the local machine succeeds (failed=0)
#
# Other registered hosts (jolly, tux, artus, margo, hp440g5) cannot be
# meaningfully smoke-tested from a different machine because they're all
# ansible_connection: local. Run this script ON each host to verify its
# own state.

set -eu

cd "$(dirname "$0")/.."

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
RESET='\033[0m'

step() { printf '%b[smoketest]%b %s\n' "$YELLOW" "$RESET" "$*"; }
ok()   { printf '%b[smoketest]%b %s\n' "$GREEN"  "$RESET" "$*"; }
fail() { printf '%b[smoketest]%b %s\n' "$RED"    "$RESET" "$*" >&2; exit 1; }

# ---------- syntax checks ----------
for play in ansible/site.yml ansible/playbooks/bootstrap.yml ansible/playbooks/terminal.yml; do
  step "syntax-check $play"
  ansible-playbook "$play" --syntax-check >/dev/null
done
ok "all three entry playbooks parse"

# ---------- local --check ----------
HOST="$(hostname -s 2>/dev/null || hostname)"
HOST_VARS="ansible/inventory/host_vars/${HOST}.yml"

if [ ! -f "$HOST_VARS" ]; then
  ok "no host_vars/${HOST}.yml — skipping --check (host is not registered)"
  exit 0
fi

step "site.yml --check -l $HOST"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

if ansible-playbook ansible/site.yml -l "$HOST" --check >"$LOG" 2>&1; then
  tail -2 "$LOG"
  if grep -q 'failed=0' "$LOG"; then
    ok "site.yml --check clean for $HOST"
  else
    fail "site.yml --check reports failures (see $LOG)"
  fi
else
  cat "$LOG"
  fail "site.yml --check exited non-zero"
fi
