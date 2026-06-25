#!/usr/bin/env bash
# Bridge a clipboard image into a REMOTE Claude Code session (Mac-only).
#
# Triggered by a kitty keybinding (see kitty.conf: map kitty_mod+i ...). Runs on
# the local Mac, because that's where the clipboard lives. Claude Code on the VM
# can't read the Mac clipboard and there's no terminal protocol for image paste
# over ssh/mosh, so instead we:
#   1. dump the clipboard image to a temp PNG (pngpaste)
#   2. scp it to the remote host
#   3. type the absolute remote path into the active kitty window via remote
#      control, so you can reference it in your prompt and hit enter yourself.
#
# No-ops cleanly on non-Mac or when there's no image in the clipboard.
set -euo pipefail

# --- config -----------------------------------------------------------------
# ssh target of the box running Claude Code. Override per-session via env.
REMOTE="${CLAUDE_CLIP_REMOTE:-pars@fkarg.de}"
# ----------------------------------------------------------------------------

# kitty launched from the macOS GUI inherits a minimal PATH without Homebrew, so
# pngpaste (and a brew-installed kitty) aren't found. Prepend the usual brew bins
# for both Apple Silicon and Intel.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

notify() {
  osascript -e "display notification \"$1\" with title \"claude-paste-image\"" 2>/dev/null || true
}
fail() { notify "$1"; exit 0; }

command -v pngpaste >/dev/null 2>&1 || fail "pngpaste not installed — run: brew install pngpaste"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
img="$tmpdir/clip.png"

# pngpaste exits non-zero if the clipboard holds no image.
pngpaste "$img" >/dev/null 2>&1 || fail "No image in the clipboard"

name="clip-$(date +%Y%m%d-%H%M%S).png"
# Resolve the remote $HOME, make the target dir, echo the absolute path back.
remote_dir="$(ssh "$REMOTE" 'd="$HOME/.cache/claude-clip"; mkdir -p "$d"; printf "%s" "$d"')" \
  || fail "ssh to $REMOTE failed"
remote_path="$remote_dir/$name"

scp -q "$img" "$REMOTE:$remote_path" || fail "scp to $REMOTE failed"

# Type the path (plus a trailing space) into the active window. Sent over
# mosh/zellij into Claude Code's input; no newline, so you review and submit.
kitty_bin="$(command -v kitty || true)"
[ -n "$kitty_bin" ] || kitty_bin="/Applications/kitty.app/Contents/MacOS/kitty"
"$kitty_bin" @ send-text --match recent:0 "$remote_path " \
  || fail "kitty remote control failed (allow_remote_control / listen_on set?)"
