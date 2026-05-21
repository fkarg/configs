# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal configuration monorepo driving three loosely-coupled subsystems:

- **Ansible** (`ansible/`) — the active provisioning layer, shared across all hosts (Linux and macOS).
- **NixOS** (`nixos/`) — declarative system config for the NixOS machines (`artus`, `margo`, `jolly`, …). Not all hosts use this.
- **Dotfiles** (`dotconfig/`) — raw config trees (fish/nvim/kitty/hypr/lf/broot) consumed by the Ansible roles via symlink.

`bootstrap.sh` is the green-field entrypoint that installs Ansible and runs `ansible-pull` against this repo. `coding-agents/` is a generator that fans out a single agent definition to four CLIs (Claude Code, OpenCode, Codex, Copilot).

## Ansible architecture

The non-obvious bits a reader can't infer from a quick `ls`:

- **Single entrypoint:** `ansible/site.yml` loops over each host's `host_roles` list and applies roles individually, tagging each by role name. There is no per-host playbook — host identity comes from `ansible/inventory/host_vars/<name>.yml`, which sets `host_roles` plus host-specific vars.
- **Push vs. pull duality.** `ansible-playbook site.yml -l <host>` (push) uses the inventory; `ansible-pull` (on-host) sets `inventory_hostname=localhost`, so host_vars are resolved via `-e host_id=<name>` and an explicit `include_vars` in `site.yml`'s pre_tasks. When editing `site.yml` or host_var loading, keep both paths working.
- **Role layering is intentional.** `base` is universally safe (no firewall, no hostname rewrite, no swap). `server_hardening` is the opt-in layer for production VMs (UFW, fail2ban, swap, hostname-set). `personal` is private-repos + cron. `terminal` is a special generic-VM profile that resolves to the current machine — see `host_vars/terminal.yml`. Don't add destructive defaults to `base`.
- **`confirm_overwrite=false` by default.** `terminal_dotfiles` skips symlinking over real config directories (fish/kitty/nvim/broot create their own on first launch). Pass `-e confirm_overwrite=true` to force-overwrite; ignored under `--check` for safety.
- **`group_vars/all.yml` holds identity + cross-role config** (git identity, `home_dir` computed from OS, `repos_list`, `repo_root`). Roles read these rather than redefining defaults.

### Common commands

```sh
# Apply to one host (push from workstation, host must be in inventory)
ansible-playbook ansible/site.yml -l caeli
ansible-playbook ansible/site.yml -l caeli --check --diff           # dry-run
ansible-playbook ansible/site.yml -l caeli --tags fish              # subset by role/tag
ansible-playbook ansible/site.yml -l caeli --tags coding_agents

# Generic VM/server (no per-host file, base + terminal_dotfiles + coding_agents)
ansible-playbook ansible/site.yml -l terminal

# On-host pull mode (host_id required because inventory_hostname is localhost)
ansible-pull -U git@github.com:fkarg/configs.git ansible/site.yml -e host_id=$(hostname)

# First-boot SSH hardening of a fresh Debian/Ubuntu box (run as root@22)
ansible-playbook ansible/playbooks/bootstrap.yml -l new-host \
  -e ansible_user=root -e ansible_port=22 -e bootstrap_user=pars

# Smoketest
./scripts/ansible_smoketest.sh
```

After adding a host: create `ansible/inventory/host_vars/<name>.yml` (must set `host_roles`) and add an entry in `ansible/inventory/hosts.yml`.

## NixOS layout

- `nixos/machines/<host>.nix` — host-specific module. Not every host here is currently live; `configuration.nix` at the repo root is a reference entrypoint, not the authoritative one for every machine.
- `nixos/shared/` — split into `base-system.nix`, `networking.nix`, `desktops/` (Hyprland), `programs/`, `packages/`, `policy/`, `users/`, `hardware/`. New cross-host plumbing belongs here.
- The live entrypoint on a host is typically `/etc/nixos/configuration.nix`, which imports this repo via `/etc/nixos/configs`. Machine-local `hardware-configuration.nix` stays on the host.
- For `jolly`, prefer `nixos-rebuild boot` (apply on next boot) over `switch` to avoid breaking the live graphical stack. See `docs/jolly.md`.

## coding-agents

Single-source agent definitions in `coding-agents/source/*.md` (opencode-flavored frontmatter). `build.py` renders per-tool variants into `coding-agents/generated/` (gitignored). The `coding_agents` Ansible role runs `build.py` then symlinks variants into `~/.claude/agents/`, `~/.config/opencode/agents/`, `~/.codex/agents/`, `~/.copilot/agents/`.

Edit only `source/<name>.md` — never the generated files. Permission semantics translate as documented in `coding-agents/README.md` (e.g. `edit: deny` strips Edit/Write/NotebookEdit from the Claude variant). Deleting `source/<name>.md` does **not** auto-remove existing symlinks — clean those up by hand.

To rebuild and resync after editing an agent:

```sh
ansible-playbook ansible/site.yml -l <host> --tags coding_agents
```

## Conventions

- No tests / no lint. Validate Ansible changes with `--check --diff` against a real host, or `scripts/ansible_smoketest.sh`.
- Commit messages follow the existing prefix style: `ansible:`, `nixos:`, `fish:`, `claude:`, `kvm:`, etc. — scope first, then a short imperative summary.
