#!/usr/bin/env bash
set -euo pipefail

sync_script="$(cd "$(dirname "$0")/.." && pwd)/scripts/agent-sync"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

home_dir="$test_root/home"
fake_bin="$test_root/bin"
mkdir -p "$home_dir" "$fake_bin"

cat >"$fake_bin/ssh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SSH_ARGS_LOG"
case "$*" in
*"ls -1 .claude/projects"*)
	printf '%s\n' \
		-home-pars-Coding-alpha \
		-home-pars-Coding-beta
	;;
esac
EOF

cat >"$fake_bin/rsync" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "--help" ]; then
	printf '%s\n' '  --info=FLAGS'
	exit 0
fi
printf '%s\n' "$*" >>"$RSYNC_ARGS_LOG"
EOF
chmod +x "$fake_bin/ssh" "$fake_bin/rsync"

progress_args="$test_root/progress-args.log"
progress_output="$test_root/progress-output.log"
ssh_args="$test_root/ssh-args.log"
AGENT_SYNC_PROGRESS=1 RSYNC_ARGS_LOG="$progress_args" SSH_ARGS_LOG="$ssh_args" \
	HOME="$home_dir" PATH="$fake_bin:$PATH" "$sync_script" pull \
	>"$progress_output" 2>&1

escape="$(printf '\033')"
grep -F "${escape}[s[pull 1/2] -home-pars-Coding-alpha" "$progress_output" || {
	cat "$progress_output" >&2
	echo 'missing initial two-line dashboard' >&2
	exit 1
}
grep -F "${escape}[u${escape}[J[pull 2/2] -home-pars-Coding-beta" "$progress_output"
grep -F "${escape}[u${escape}[J[pull codex] .codex/sessions" "$progress_output"
[ "$(grep -F -c "${escape}[s" "$progress_output")" -eq 1 ]
[ "$(grep -F -c "${escape}[u${escape}[J" "$progress_output")" -eq 2 ]
[ "$(grep -c -- '--info=progress2' "$progress_args")" -eq 3 ]
[ "$(grep -c -- '--human-readable' "$progress_args")" -eq 3 ]
[ "$(grep -c -- '-x' "$progress_args")" -eq 3 ]
[ "$(grep -c -- '-x' "$ssh_args")" -eq 2 ]

quiet_args="$test_root/quiet-args.log"
quiet_output="$test_root/quiet-output.log"
RSYNC_ARGS_LOG="$quiet_args" SSH_ARGS_LOG="$ssh_args" \
	HOME="$home_dir" PATH="$fake_bin:$PATH" \
	"$sync_script" pull >"$quiet_output" 2>&1

if grep -F -- '--info=progress2' "$quiet_args" >/dev/null; then
	echo 'non-interactive sync unexpectedly enabled rsync progress' >&2
	exit 1
fi
if grep -F -- '[pull ' "$quiet_output" >/dev/null; then
	echo 'non-interactive sync unexpectedly printed folder progress' >&2
	exit 1
fi

printf 'agent-sync progress tests passed\n'
