#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/home/.codex/account-auth/kolai" "$tmpdir/home/.codex/account-auth/personal" "$tmpdir/bin"

cat > "$tmpdir/home/.codex/account-auth/kolai/auth.json" <<'JSON'
{
  "tokens": {
    "account_id": "acct-same",
    "access_token": "token-kolai"
  }
}
JSON

cat > "$tmpdir/home/.codex/account-auth/personal/auth.json" <<'JSON'
{
  "tokens": {
    "account_id": "acct-same",
    "access_token": "token-personal"
  }
}
JSON

cat > "$tmpdir/bin/curl" <<'SH'
#!/usr/bin/env bash
cat <<'JSON'
{
  "plan_type": "team",
  "rate_limit": {
    "primary_window": {
      "used_percent": 21,
      "limit_window_seconds": 18000,
      "reset_after_seconds": 9060
    },
    "secondary_window": {
      "used_percent": 84,
      "limit_window_seconds": 604800,
      "reset_after_seconds": 126000
    }
  }
}
JSON
SH
chmod +x "$tmpdir/bin/curl"

output="$(HOME="$tmpdir/home" PATH="$tmpdir/bin:$PATH" "$repo_root/scripts/codex-account" list)"

printf '%s\n' "$output" | grep -F "warning: same Codex account as profile 'kolai'" >/dev/null
