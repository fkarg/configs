#!/bin/sh
# Green-field one-paste entrypoint. Pull-mode bootstrap for a fresh host.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/fkarg/configs/master/bootstrap.sh | sh
#
# Env vars:
#   BOOTSTRAP_HOST_ID — if set, runs ansible/site.yml with -e host_id=<value>
#                        instead of the ad-hoc terminal.yml.
#   CONFIGS_REPO_URL  — override the default repo URL (mainly for testing).

set -eu

REPO_URL="${CONFIGS_REPO_URL:-https://github.com/fkarg/configs.git}"
HOST_ID="${BOOTSTRAP_HOST_ID:-}"

log() { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[bootstrap]\033[0m %s\n' "$*" >&2; exit 1; }

# ----- distro detection -----
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  DISTRO="${ID:-unknown}"
else
  case "$(uname -s)" in
    Darwin) DISTRO=darwin ;;
    *)      DISTRO=unknown ;;
  esac
fi
log "detected distro: $DISTRO"

# Use sudo only if not already root. A fresh Hetzner-style VM logged into as
# root won't have sudo installed yet.
if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO=sudo; fi

# ----- install ansible if missing -----
if ! command -v ansible-pull >/dev/null 2>&1; then
  log "installing ansible..."
  case "$DISTRO" in
    debian|ubuntu)
      $SUDO apt-get update
      $SUDO apt-get install -y ansible
      ;;
    fedora|rhel|centos|rocky|almalinux)
      $SUDO dnf install -y ansible
      ;;
    arch|manjaro)
      $SUDO pacman -Sy --noconfirm ansible
      ;;
    darwin)
      if ! command -v brew >/dev/null 2>&1; then
        die "Homebrew is required on macOS. Install from https://brew.sh/ first."
      fi
      brew install ansible
      ;;
    *)
      die "Unknown distro '$DISTRO' — install ansible manually and re-run."
      ;;
  esac
else
  log "ansible already installed: $(ansible --version | head -1)"
fi

# ----- choose playbook + extra vars -----
if [ -n "$HOST_ID" ]; then
  PLAYBOOK="ansible/site.yml"
  EXTRA_VARS="-e host_id=$HOST_ID"
  log "using site.yml with host_id=$HOST_ID"
else
  PLAYBOOK="ansible/playbooks/terminal.yml"
  EXTRA_VARS=""
  log "using ad-hoc terminal.yml (base + terminal_dotfiles)"
fi

# ----- run ansible-pull -----
log "running ansible-pull from $REPO_URL ..."
# shellcheck disable=SC2086
ansible-pull \
  --clean \
  --accept-host-key \
  -U "$REPO_URL" \
  "$PLAYBOOK" \
  $EXTRA_VARS \
  "$@"

log "done."
