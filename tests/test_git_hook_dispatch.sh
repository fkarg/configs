#!/usr/bin/env bash
set -euo pipefail

dispatcher="$(cd "$(dirname "$0")/.." && pwd)/ansible/roles/terminal_dotfiles/files/git-hooks/dispatch"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

repo="$test_root/repo"
worktree="$test_root/linked"
configured_hooks="$test_root/configured-hooks"
log="$test_root/hook.log"

git init -q "$repo"
git -C "$repo" config user.name "Hook Test"
git -C "$repo" config user.email "hook-test@example.invalid"
git -C "$repo" config commit.gpgSign false
mkdir -p "$configured_hooks"
ln -s "$dispatcher" "$configured_hooks/post-commit"
git -C "$repo" config core.hooksPath "$configured_hooks"

printf 'base\n' >"$repo/tracked.txt"
git -C "$repo" add tracked.txt
git -C "$repo" commit -q -m "chore: initial"
git -C "$repo" worktree add -q -b linked "$worktree"
worktree="$(cd "$worktree" && pwd -P)"

common_hook="$repo/.git/hooks/post-commit"
cat >"$common_hook" <<'EOF'
#!/usr/bin/env bash
printf 'common:%s\n' "$PWD" >>"$DISPATCH_TEST_LOG"
EOF
chmod +x "$common_hook"

DISPATCH_TEST_LOG="$log" git -C "$worktree" commit -q --allow-empty -m "test: common hook"
grep -Fx "common:$worktree" "$log"

rm "$common_hook"
mkdir -p "$worktree/.githooks"
cat >"$worktree/.githooks/post-commit" <<'EOF'
#!/usr/bin/env bash
printf 'tracked:%s\n' "$PWD" >>"$DISPATCH_TEST_LOG"
EOF
chmod +x "$worktree/.githooks/post-commit"

DISPATCH_TEST_LOG="$log" git -C "$worktree" commit -q --allow-empty -m "test: tracked hook"
grep -Fx "tracked:$worktree" "$log"

printf 'git hook dispatcher tests passed\n'
