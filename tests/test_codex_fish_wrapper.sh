#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin"
cat > "$tmpdir/bin/codex" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@"
SH
chmod +x "$tmpdir/bin/codex"

output="$(PATH="$tmpdir/bin:$PATH" fish -c "source '$repo_root/dotconfig/fish/functions/codex.fish'; codex exec review")"

expected=$'--approve-for-me\nexec\nreview'
test "$output" = "$expected"
