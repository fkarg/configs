# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Read `README.md` first — it covers the user-facing flow: client roles, the role-layer table (`bootstrap` / `base` / `server_hardening` / `terminal_dotfiles` / `personal` / `graphical_dotfiles` / `os_macos` / `coding_agents`), and bootstrap/usage commands. This file only documents the *non-obvious* architecture and editing constraints that aren't in README.

## What this repo is

Personal configuration monorepo driving three loosely-coupled subsystems:

- **Ansible** (`ansible/`) — the active provisioning layer, shared across all hosts (Linux and macOS).
- **NixOS** (`nixos/`) — declarative system config for the NixOS machines (`artus`, `margo`, `jolly`, …). Not every host uses it.
- **Dotfiles** (`dotconfig/`) — raw config trees (fish/nvim/kitty/hypr/lf/broot) consumed by the Ansible roles via symlink.

`bootstrap.sh` is the green-field entrypoint; `coding-agents/` is a generator that fans out one agent definition to four CLIs.

## Ansible architecture (non-obvious bits)

- **Single entrypoint.** `ansible/site.yml` loops over each host's `host_roles` list and applies roles individually, tagging each by role name. There is no per-host playbook — host identity comes from `ansible/inventory/host_vars/<name>.yml`, which sets `host_roles` plus host-specific vars.
- **Push vs. pull duality.** Push (`ansible-playbook -l <host>`) uses the inventory. Pull (`ansible-pull` on-host) sets `inventory_hostname=localhost`, so host_vars are resolved via `-e host_id=<name>` and an explicit `include_vars` in `site.yml`'s pre_tasks. When touching `site.yml` or host_var loading, keep both paths working.
- **Role layering intent.** `base` is universally safe — never add firewall, hostname rewrite, swap, or other destructive defaults to it. Those belong in `server_hardening`. The `terminal` host profile (`host_vars/terminal.yml`) deliberately excludes `personal` and `server_hardening` so it's safe to apply on any unfamiliar VM.
- **`confirm_overwrite=false` by default.** `terminal_dotfiles` skips symlinking over real config directories (fish/kitty/nvim/broot create their own on first launch). Pass `-e confirm_overwrite=true` to force; ignored under `--check` for safety.
- **`group_vars/all.yml` holds shared identity + cross-role config** (git identity, `home_dir` computed from OS, `repos_list`, `repo_root`). Roles read these rather than redefining defaults.

Validating changes: there are no tests/lint. Use `--check --diff` against a real host, or `./scripts/ansible_smoketest.sh`. Subset by role with `--tags <role>`.

## NixOS layer

README covers the high-level rules (live entrypoint is `/etc/nixos/configuration.nix`, host-specific behavior under `nixos/machines/`, shared desktop plumbing under `nixos/shared/`, `jolly` upgrades via next-boot not live-switch). Beyond that:

- `nixos/shared/` is split into `base-system.nix`, `networking.nix`, `desktops/` (Hyprland), `programs/`, `packages/`, `policy/`, `users/`, `hardware/`. New cross-host plumbing belongs here.
- Repo-root `configuration.nix` is a reference entrypoint, not authoritative for every machine. Machine-local `hardware-configuration.nix` stays on the host.
- See `docs/jolly.md` for the recovery context behind the boot-vs-switch rule.

## coding-agents

Single-source agent definitions in `coding-agents/source/*.md` (opencode-flavored frontmatter). `build.py` renders per-tool variants into `coding-agents/generated/` (gitignored). The `coding_agents` Ansible role runs `build.py` then symlinks variants into `~/.claude/agents/`, `~/.config/opencode/agents/`, `~/.codex/agents/`, `~/.copilot/agents/`.

- Edit only `source/<name>.md` — never the generated files.
- Permission translation rules live in `coding-agents/README.md` (e.g. `edit: deny` strips Edit/Write/NotebookEdit from the Claude variant).
- Deleting `source/<name>.md` does **not** auto-remove existing symlinks — clean those up by hand.
- Resync after edits: `ansible-playbook ansible/site.yml -l <host> --tags coding_agents`.

## Conventions

Commit messages: scope prefix first, then short imperative summary — e.g. `ansible:`, `nixos:`, `fish:`, `claude:`, `kvm:`. Match the existing style in `git log`.
