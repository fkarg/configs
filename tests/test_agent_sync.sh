#!/usr/bin/env bash
set -euo pipefail

# Regression: an untrappable interruption used to leave ~/.agent-sync.lock
# behind for an hour because the directory-based lock could not be released.
sync_script="$(cd "$(dirname "$0")/.." && pwd)/scripts/agent-sync"
test_root="$(mktemp -d)"
sync_pid=""

cleanup() {
	if [ -n "$sync_pid" ] && kill -0 "$sync_pid" 2>/dev/null; then
		kill -TERM -- "-$sync_pid" 2>/dev/null || true
		wait "$sync_pid" 2>/dev/null || true
	fi
	rm -rf "$test_root"
}
trap cleanup EXIT

home_dir="$test_root/home"
fake_bin="$test_root/bin"
mkdir -p "$home_dir/.codex/sessions" "$fake_bin"
printf 'settled transcript\n' >"$home_dir/.codex/sessions/rollout.jsonl"
touch -d '3 minutes ago' "$home_dir/.codex/sessions/rollout.jsonl"

cat >"$fake_bin/ssh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$fake_bin/rsync" <<EOF
#!/usr/bin/env bash
calls_file="$test_root/rsync-calls"
calls=0
[ -f "\$calls_file" ] && calls="\$(cat "\$calls_file")"
calls=\$((calls + 1))
printf '%s\\n' "\$calls" >"\$calls_file"
if [ "\$calls" -eq 1 ]; then
	touch "$test_root/rsync-started"
	exec sleep 30
fi
EOF
chmod +x "$fake_bin/ssh" "$fake_bin/rsync"

setsid env --default-signal=INT HOME="$home_dir" PATH="$fake_bin:$PATH" "$sync_script" push \
	>"$test_root/agent-sync.log" 2>&1 &
sync_pid=$!

for _ in {1..50}; do
	[ -e "$test_root/rsync-started" ] && break
	sleep 0.1
done
[ -e "$test_root/rsync-started" ] || {
	cat "$test_root/agent-sync.log"
	echo 'agent-sync never started rsync' >&2
	exit 1
}

env HOME="$home_dir" PATH="$fake_bin:$PATH" "$sync_script" push \
	>"$test_root/concurrent.log" 2>&1
[ "$(cat "$test_root/rsync-calls")" -eq 1 ] || {
	echo 'agent-sync allowed concurrent full syncs' >&2
	exit 1
}
grep -F 'another run holds the lock, skipping' "$test_root/concurrent.log" >/dev/null

kill -KILL -- "-$sync_pid"

set +e
wait "$sync_pid"
status=$?
set -e
[ "$status" -eq 137 ] || {
	echo "expected SIGKILL exit status 137, got $status" >&2
	exit 1
}

env HOME="$home_dir" PATH="$fake_bin:$PATH" "$sync_script" push \
	>"$test_root/retry.log" 2>&1
[ "$(cat "$test_root/rsync-calls")" -eq 2 ] || {
	cat "$test_root/retry.log" >&2
	echo 'agent-sync did not run after its predecessor was killed' >&2
	exit 1
}

printf 'agent-sync stale-lock recovery test passed\n'
