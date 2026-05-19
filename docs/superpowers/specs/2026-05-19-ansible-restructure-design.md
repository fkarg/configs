# Ansible Restructure — Design Spec

**Date:** 2026-05-19
**Status:** Approved (pending spec review)
**Author:** Felix + Claude

## Goal

Restructure the ansible portion of this `configs` repo from a flat playbook-with-scattered-tasks shape into a role-based architecture. Preserve `ansible-pull` usability (single-URL invocation, no preconditions beyond curl + sudo on a fresh machine) while gaining modularity, composability via per-host role lists, and orthogonal tag filtering.

A secondary goal is to support fresh-server bootstrap (Hetzner-style VMs): SSH hardening, deploy-user creation, port move — modeled on the existing `bootstrap` + `base` role pair from `~/Coding/infrastructure`.

## Non-Goals

- NixOS linking automation is **out of scope** for this restructure. Manual `/etc/nixos` setup remains acceptable for now; `tasks/nixos.yml` and `templates/nixosconfig.j2` are deleted with no replacement.
- No new dotfile management (fish/nvim/i3/etc. configs themselves are unchanged; only the way ansible deploys them changes).
- No migration to flakes, nixos-hardware fetchgit, or any of the `README.md` TODO items.

## Constraints

1. **Pull-from-URL must remain a short command.** Bootstrapping a stock machine should require at most one paste.
2. **Push-from-workstation over SSH** must also work (for managing remote VMs).
3. **Default behavior on an unregistered host = terminal-only config.** No GUI/dotfile assumptions, no hostname rewrites.
4. **Backwards compat with current ansible-pull URL is not required** — README will document the new commands and old `-e client_role=...` is allowed to break.
5. Repo is git-versioned; nothing is truly irreversible. Risky steps are still sequenced to be verifiable in isolation.

## Architecture

### Directory layout

```
configs/
├── ansible.cfg                       # at root so ansible-pull/-playbook auto-discover
├── bootstrap.sh                      # green-field one-paste: installs ansible, runs ansible-pull
├── ansible/
│   ├── site.yml                      # main playbook: host_id → host_vars → roles list
│   ├── playbooks/
│   │   ├── bootstrap.yml             # runs bootstrap role only (first-boot hardening)
│   │   └── terminal.yml              # ad-hoc: base + terminal_dotfiles for unregistered hosts
│   ├── inventory/
│   │   └── hosts.yml                 # static inventory (for push-mode runs from workstation)
│   ├── group_vars/
│   │   └── all.yml                   # global defaults (replaces today's defaults/main.yml)
│   ├── host_vars/
│   │   ├── caeli.yml                 # identity + roles list per host
│   │   ├── jolly.yml
│   │   └── …
│   └── roles/
│       ├── bootstrap/                # root@22 → pars@<new_port>, ufw, sshd hardening
│       ├── base/                     # mosh, fail2ban, swap, sysctls, timezone, optional hostname
│       ├── terminal_dotfiles/        # fish, nvim, git config, repos clones
│       ├── graphical_dotfiles/       # kitty, i3, hyprland, broot, fonts, background, todo
│       ├── os_macos/                 # homebrew formulae+casks, Sparkle/MS/Keystone autoupdate disable
│       └── coding_agents/            # opencode/claude/codex/copilot agent symlinks
```

`ansible.cfg` at the repo root keeps both `ansible-pull` and `ansible-playbook` working without env vars or chdir. It points `inventory = ansible/inventory/hosts.yml`, `roles_path = ansible/roles`, `host_vars` paths under `ansible/`, etc.

### Role catalog (6 roles)

| Role | Runs as | When | Purpose |
|---|---|---|---|
| `bootstrap` | `root` on port 22 | First-boot only, separate playbook | Create `pars` user (configurable via `bootstrap_user`), copy SSH keys from root, open new SSH port in ufw, switch sshd to new port, disable root login + password auth. Cannot continue in same play afterward. |
| `base` | `pars` on the new SSH port | First role on every host listed in `site.yml`, plus first in the ad-hoc `terminal.yml` | apt updates, common packages, mosh + wrapper, fail2ban, ufw rules, swap, zswap, sysctls, timezone. Hostname only set when `server_hostname` is explicitly defined. |
| `terminal_dotfiles` | host user | Every host | Clones `~/configs`, templates `.gitconfig`, links `~/.config/{fish,nvim,vim}`, templates fish config, clones `text_zeug`. |
| `graphical_dotfiles` | host user | GUI hosts only | Links `~/.config/{kitty,hypr,broot}`, templates i3 + i3status + on_startup, todo config, Fontin font, background, gtd + finances clones. Gated by `ansible_facts['system'] == 'Linux'` for i3/hyprland-specific bits. |
| `os_macos` | host user | macOS hosts | Homebrew install if missing, formulae + casks (top-level invariant preserved), Sparkle / MS / Keystone autoupdate disable. Gated by `ansible_facts['system'] == 'Darwin'`. |
| `coding_agents` | host user | Hosts that want it | Runs `coding-agents/build.py`, then symlinks generated agent files into `~/.config/opencode/agents`, `~/.claude/agents`, `~/.codex/agents`, `~/.copilot/agents`. Verbatim port of today's logic. |

### Host model

`ansible/host_vars/<name>.yml` declares connection identity, machine-specific knobs, and a `host_roles:` list. `site.yml` loops over that list with `include_role` and applies role-name tags automatically.

(`host_roles` rather than plain `roles` because `roles:` is a reserved play-level directive in Ansible; using it as a variable name works but invites confusion.)

Example shapes:

```yaml
# ansible/host_vars/caeli.yml — personal mac
ansible_user: felix
ansible_port: 22
host_roles:
  - terminal_dotfiles
  - os_macos
  - graphical_dotfiles
  - coding_agents

username: felix
cowfile: llama
direnv: true
zoxide: true
brew_packages_common: [...]
brew_casks_common:    [...]
```

```yaml
# ansible/host_vars/jolly.yml — desktop linux
ansible_user: pars
ansible_port: 2244
server_hostname: jolly   # opt-in; base role only sets hostname when defined
host_roles:
  - base
  - terminal_dotfiles
  - graphical_dotfiles
  - coding_agents

username: pars
lan: enp10s0
battery: false
pactl_sink_name: alsa_output.usb-Generic_USB_Audio-00.HiFi__Speaker__sink
```

```yaml
# ansible/host_vars/hetzner-vm-foo.yml — server, no GUI
ansible_user: pars
ansible_port: 2244
server_hostname: hetzner-vm-foo
host_roles:
  - base
  - terminal_dotfiles
```

For ad-hoc hosts that don't warrant a `host_vars/` entry (reusable terminal-only template for short-lived VMs), the `ansible/playbooks/terminal.yml` playbook applies `base + terminal_dotfiles` with sensible defaults and **does not set the hostname**.

`site.yml` orchestrator:

```yaml
- hosts: all
  gather_facts: true
  pre_tasks:
    - assert:
        that: host_roles is defined and host_roles | length > 0
        fail_msg: "Host '{{ inventory_hostname }}' has no host_roles list in host_vars."
        tags: [always]
  tasks:
    - include_role:
        name: "{{ item }}"
        apply: { tags: ["{{ item }}"] }
      loop: "{{ host_roles }}"
```

### Tag scheme

Two orthogonal axes, both available simultaneously:

**Role tags** — auto-applied per `include_role` in `site.yml`. Values match role names: `bootstrap`, `base`, `terminal_dotfiles`, `graphical_dotfiles`, `os_macos`, `coding_agents`. Use to re-run a whole role (`--tags graphical_dotfiles`).

**Concern tags** — declared on tasks inside roles. Cross-role values: `fish`, `nvim`, `git`, `repos`, `kitty`, `i3`, `hyprland`, `broot`, `fonts`, `todo`, `ssh`, `firewall`, `swap`, `mosh`, `brew_formulae`, `brew_casks`, `autoupdates`. Use to refresh one concern across whichever roles it touches (`--tags fish`).

Plus `always` on identity/fact-gathering pre_tasks so they run regardless of `--tags` filtering.

### Invocation UX

**A. Fresh server, push from workstation** (root login on port 22, key already in `/root/.ssh/authorized_keys`):

```bash
ansible-playbook ansible/playbooks/bootstrap.yml -l new-host \
  -e ansible_user=root -e ansible_port=22 -e bootstrap_user=pars
```

After completion, the host accepts `pars@<new_port>` only. Workstation then adds `host_vars/new-host.yml` and runs `site.yml`.

**B. Fresh box, single-paste pull-mode**:

```bash
curl -fsSL https://raw.githubusercontent.com/fkarg/configs/master/bootstrap.sh | bash
```

`bootstrap.sh` detects the distro (apt/dnf/brew), installs ansible if missing, then runs `ansible-pull -U https://github.com/fkarg/configs.git ansible/playbooks/terminal.yml`. Result: host has `base + terminal_dotfiles`, no registration needed. Override registration with env: `BOOTSTRAP_HOST_ID=jolly bash bootstrap.sh` triggers `ansible/site.yml` with `-e host_id=jolly` instead.

**C. Registered host, ongoing config**:

```bash
# from workstation (push)
ansible-playbook ansible/site.yml -l caeli

# on-host (pull)
ansible-pull -U git@github.com:fkarg/configs.git ansible/site.yml -e host_id=$(hostname)
```

`site.yml` resolves which host_vars file to load via `host_id | default(inventory_hostname)`. Under `ansible-pull`, `inventory_hostname` is always `localhost`, so `host_id` must be passed explicitly. Under `ansible-playbook -l caeli`, `inventory_hostname == caeli` already, so no extra-var is needed.

### Reusable helper: `link_dotdir.yml`

The current "stat → optionally remove → symlink" pattern appears 5+ times across `terminal.yml` and `configs_graphical.yml`. Extract to a single task file at `roles/terminal_dotfiles/tasks/link_dotdir.yml`. `terminal_dotfiles` consumes it with `include_tasks`; `graphical_dotfiles` consumes it across the role boundary with:

```yaml
- include_role:
    name: terminal_dotfiles
    tasks_from: link_dotdir
  vars: { link_src: kitty, link_dest: ~/.config/kitty }
  tags: [kitty]
```

This keeps the helper DRY without inventing a separate "shared" role and without depending on `playbook_dir` resolution. The helper itself takes only inputs and has no side effects beyond the symlink:

```yaml
# roles/terminal_dotfiles/tasks/link_dotdir.yml
# expects: link_src (subpath under dotconfig/), link_dest (target ~/.config/X path)
- stat: { path: "{{ link_dest }}" }
  register: _stat
- file: { path: "{{ link_dest }}", state: absent }
  when:
    - _stat.stat.exists
    - _stat.stat.isdir | default(false)
    - not (_stat.stat.islnk | default(false))
    - confirm_overwrite | default(false) | bool
    - not ansible_check_mode
- file:
    src: "~/{{ configs_repo }}/{{ dotconfigdir }}/{{ link_src }}"
    dest: "{{ link_dest }}"
    state: link
  when: not (_stat.stat.exists and _stat.stat.isdir and not _stat.stat.islnk
             and not (confirm_overwrite | default(false) | bool))
```

Callers inside `terminal_dotfiles` shrink to three-line `include_tasks` blocks with a `tags:` per concern.

## Migration mapping

| Current location | New location |
|---|---|
| `general.yml` | deleted (replaced by `ansible/site.yml`) |
| `tasks/main.yml` | deleted (stale duplicate of general.yml) |
| `tasks/terminal.yml` | split into `roles/terminal_dotfiles/tasks/main.yml` + `roles/terminal_dotfiles/tasks/link_dotdir.yml` (shared helper, also called from graphical_dotfiles) |
| `tasks/configs_graphical.yml` | `roles/graphical_dotfiles/tasks/main.yml` |
| `tasks/macos_packages.yml` | `roles/os_macos/tasks/packages.yml` |
| `tasks/macos_disable_autoupdates.yml` | `roles/os_macos/tasks/autoupdates.yml` |
| `tasks/coding_agents.yml` | `roles/coding_agents/tasks/main.yml` |
| `tasks/terminal_extended.yml` (cron) | `roles/base/tasks/cron.yml` (gated by var) |
| `tasks/nixos.yml` | **deleted** (nixos linking remains manual) |
| `tasks/packages.yml`, `packages_terminal.yml`, `packages_terminal_full.yml`, `packages_graphical.yml`, `nix_packages.yml`, `testing.yml` | **deleted** (all unused) |
| `defaults/main.yml` | `ansible/group_vars/all.yml` |
| `handlers/main.yml` | `restart i3`, `install br` → `graphical_dotfiles/handlers/main.yml`; `nixos-rebuild` handlers deleted |
| `vars/<role>.yml` (11 files) | restructured to `ansible/host_vars/<host>.yml` with a `host_roles:` list. `vars/snb.yml`, `vars/novo.yml`, `vars/serf.yml`, `vars/terminal.yml`, `vars/desktop.yml` deleted unless their identity is needed for a still-active host |
| `templates/fishconfig.j2`, `templates/gitconfig.j2` | `roles/terminal_dotfiles/templates/` |
| `templates/i3config.j2`, `i3statusconfig.j2`, `on_startup.j2`, `todoconfig.j2` | `roles/graphical_dotfiles/templates/` |
| `templates/passive_update.j2` | `roles/base/templates/` |
| `templates/nixosconfig.j2` | **deleted** |
| `ansible/inventory` (the 2-line file) | replaced by `ansible/inventory/hosts.yml` (proper YAML listing registered hosts) |

The legacy apt-based package files are replaced inside `base`: package list becomes `base_packages` in `roles/base/defaults/main.yml`, overridable per host via `base_packages_extra`. Same shape as the infra repo.

## Sequencing

Risky to do in one shot. Each step is verifiable in `--check --diff` mode on at least one host before the next.

1. **Scaffolding.** Add `ansible.cfg` at root and empty `ansible/` skeleton (empty roles, empty site.yml). Existing `general.yml` still works.
2. **Variables.** Port `defaults/main.yml` → `ansible/group_vars/all.yml`. Port the 11 `vars/*.yml` files → `ansible/host_vars/*.yml`, adding `host_roles:` lists and identity vars. `general.yml` still references the old paths and still works.
3. **Roles.** Build out one role at a time in this order: `base` → `terminal_dotfiles` → `os_macos` → `coding_agents` → `graphical_dotfiles` → `bootstrap`. Each step moves task content from the old `tasks/*.yml` files into `roles/<x>/tasks/`, with check-mode verification against a real host.
4. **Orchestration.** Write `ansible/site.yml`, `ansible/playbooks/bootstrap.yml`, `ansible/playbooks/terminal.yml`. Verify each registered host with `--check`.
5. **Bootstrap script.** Add `bootstrap.sh` at repo root. Test against a fresh container or VM.
6. **Cutover.** Update `README.md` to document new commands. Old commands stop working after step 7.
7. **Deletion.** Remove old `tasks/`, `vars/`, `handlers/`, `defaults/`, `templates/`, `general.yml`, `ansible/inventory` (the file — the directory becomes a real directory at step 1).

## Open questions / decisions deferred

- Exact `base_packages` default list — to be derived from `tasks/packages_terminal.yml` + `tasks/packages_terminal_full.yml` + the mosh/fail2ban additions visible in `~/Coding/infrastructure/ansible/roles/base/tasks/main.yml`, but the final list happens during implementation, not here.
- Whether to also generate `ansible/inventory/hosts.yml` automatically from `host_vars/` filenames or maintain it by hand. Default: by hand; small enough.
- Vault usage. None today. Adding vault is out of scope for this restructure — revisit when first secret appears.

## Success criteria

- `ansible-playbook ansible/site.yml -l caeli --check --diff` runs cleanly and produces a diff equivalent to what `ansible-pull -U ... general.yml -e client_role=caeli --check --diff` would have produced before the restructure (modulo cosmetic ordering).
- `ansible-pull -U <repo> ansible/playbooks/terminal.yml --check` on a fresh container applies `base + terminal_dotfiles` cleanly with no host registration.
- Repo root no longer contains `tasks/`, `vars/`, `handlers/`, `defaults/`, `templates/`, or `general.yml`. All ansible content (except `ansible.cfg` and `bootstrap.sh`) lives under `ansible/`.
- `--tags fish` re-templates fish config across whichever roles contain it, without touching anything else.
