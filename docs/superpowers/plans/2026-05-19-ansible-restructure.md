# Ansible Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the ansible portion of this `configs` repo from a flat playbook + scattered tasks layout into a role-based architecture under `ansible/`, with per-host `host_roles` lists, orthogonal role+concern tags, a `bootstrap.sh` one-paste entrypoint, and both push-from-workstation and pull-from-URL invocation modes.

**Architecture:** All ansible content moves under `ansible/` (roles, playbooks, inventory, group_vars, host_vars). `ansible.cfg` stays at the repo root so both `ansible-pull` and `ansible-playbook` auto-discover it. Six roles (`bootstrap`, `base`, `terminal_dotfiles`, `graphical_dotfiles`, `os_macos`, `coding_agents`) are composed per-host via a `host_roles:` list in `host_vars/<name>.yml`, looped over by `site.yml` with `include_role`. The legacy `general.yml` / `tasks/` / `vars/` layout is preserved through migration and deleted in the final task.

**Tech Stack:** Ansible 2.16+, `community.general` collection (homebrew, ufw, osx_defaults), `ansible.posix` collection (sysctl), shell (`bootstrap.sh` POSIX-compliant).

**Testing strategy:** Ansible plays are declarative; there is no pytest-style unit framework in scope (Molecule is out of scope per spec). Verification at each task uses (a) `ansible-playbook --syntax-check` for structural correctness and (b) `ansible-playbook --check --diff` against a real host for behavioral equivalence to the pre-migration playbook. Each role port includes a check-mode verification step using a temporary single-role playbook before the orchestration task wires everything together.

**Working tree:** This plan executes on `master`. The user has explicitly OK'd this — the repo is git-versioned, every step is one commit, and rollback is `git revert`. No worktree is required.

---

## File Structure

### New files

| Path | Responsibility |
|---|---|
| `ansible.cfg` | Repo-root config; defines inventory path, roles_path, host_vars/group_vars locations, ssh args. Discovered automatically by both `ansible-pull` and `ansible-playbook`. |
| `bootstrap.sh` | Green-field one-paste entrypoint. POSIX shell. Detects distro, installs ansible, runs `ansible-pull` against `ansible/playbooks/terminal.yml` (default) or `site.yml` (if `BOOTSTRAP_HOST_ID` is set). |
| `ansible/site.yml` | Main playbook. Asserts `host_roles` is set, loops over it with `include_role`. Resolves which host_vars to load via `host_id \| default(inventory_hostname)`. |
| `ansible/playbooks/bootstrap.yml` | First-boot playbook. Runs only the `bootstrap` role. Used as root@22 to create deploy user + move SSH port. |
| `ansible/playbooks/terminal.yml` | Ad-hoc playbook. Applies `base + terminal_dotfiles` without requiring host registration. Does not set hostname. |
| `ansible/inventory/hosts.yml` | Static inventory for push-mode runs. Lists registered hosts with `ansible_host` (when remote). |
| `ansible/group_vars/all.yml` | Global defaults (port of `defaults/main.yml`). |
| `ansible/host_vars/<host>.yml` | Per-host identity + `host_roles:` list (port of `vars/<host>.yml` + connection info). One file per active host: caeli, jolly, tux, artus, margo, hp440g5. |
| `ansible/roles/base/tasks/main.yml` | Server-only base: apt updates, packages, mosh+wrapper, fail2ban, ufw, swap, sysctls, timezone, conditional hostname. |
| `ansible/roles/base/defaults/main.yml` | base_packages, base_mosh_port_range, base_ufw_rules, etc. |
| `ansible/roles/base/handlers/main.yml` | Restart SSH, Restart fail2ban, Update GRUB. |
| `ansible/roles/base/tasks/cron.yml` | Passive-update cron (from `tasks/terminal_extended.yml`), gated by var. |
| `ansible/roles/base/templates/passive_update.j2` | Cron-driven repo updater (verbatim from existing `templates/passive_update.j2`). |
| `ansible/roles/terminal_dotfiles/tasks/main.yml` | Repo clone, gitconfig template, fish/nvim/vim symlinks via helper, text_zeug clone. |
| `ansible/roles/terminal_dotfiles/tasks/link_dotdir.yml` | Reusable "stat → optionally remove → symlink" helper. Consumed via `include_tasks` here and `include_role: tasks_from: link_dotdir` from `graphical_dotfiles`. |
| `ansible/roles/terminal_dotfiles/templates/gitconfig.j2` | Verbatim from `templates/gitconfig.j2`. |
| `ansible/roles/terminal_dotfiles/templates/fishconfig.j2` | Verbatim from `templates/fishconfig.j2`. |
| `ansible/roles/terminal_dotfiles/defaults/main.yml` | enable_broot fallback, etc. |
| `ansible/roles/terminal_dotfiles/handlers/main.yml` | `install br` handler (moved from `handlers/main.yml`). |
| `ansible/roles/graphical_dotfiles/tasks/main.yml` | kitty, hyprland.conf, i3, i3status, on_startup, todo, fonts, background, gtd + finances clones, mozilla legacy symlink. |
| `ansible/roles/graphical_dotfiles/templates/i3config.j2` | Verbatim from `templates/i3config.j2`. |
| `ansible/roles/graphical_dotfiles/templates/i3statusconfig.j2` | Verbatim from `templates/i3statusconfig.j2`. |
| `ansible/roles/graphical_dotfiles/templates/on_startup.j2` | Verbatim from `templates/on_startup.j2`. |
| `ansible/roles/graphical_dotfiles/templates/todoconfig.j2` | Verbatim from `templates/todoconfig.j2`. |
| `ansible/roles/graphical_dotfiles/handlers/main.yml` | `restart i3` handler. |
| `ansible/roles/os_macos/tasks/main.yml` | Includes packages.yml + autoupdates.yml. |
| `ansible/roles/os_macos/tasks/packages.yml` | brew install + formulae/casks loop. |
| `ansible/roles/os_macos/tasks/autoupdates.yml` | Sparkle / Microsoft / Keystone disable. |
| `ansible/roles/coding_agents/tasks/main.yml` | Port of `tasks/coding_agents.yml`. Path references updated to use `role_path` instead of `playbook_dir`. |
| `ansible/roles/bootstrap/tasks/main.yml` | Adapted from `~/Coding/infrastructure/ansible/roles/bootstrap`. Renamed `bootstrap_deploy_user` default to `pars`. |
| `ansible/roles/bootstrap/defaults/main.yml` | bootstrap_user (default `pars`), bootstrap_ssh_port, etc. |
| `ansible/roles/bootstrap/handlers/main.yml` | bootstrap_restart_ssh, bootstrap_restart_ssh_socket, bootstrap_reload_systemd. |

### Files to delete in final task

`general.yml`, `tasks/main.yml`, `tasks/terminal.yml`, `tasks/configs_graphical.yml`, `tasks/macos_packages.yml`, `tasks/macos_disable_autoupdates.yml`, `tasks/coding_agents.yml`, `tasks/terminal_extended.yml`, `tasks/nixos.yml`, `tasks/packages.yml`, `tasks/packages_terminal.yml`, `tasks/packages_terminal_full.yml`, `tasks/packages_graphical.yml`, `tasks/nix_packages.yml`, `tasks/testing.yml`, `defaults/main.yml`, `defaults/`, `handlers/main.yml`, `handlers/`, `vars/*.yml`, `vars/`, `templates/*.j2`, `templates/`, `ansible/inventory` (the existing 2-line file). The dir `tasks/` is removed entirely. `templates/` is removed entirely. The orphan `vars/snb.yml`, `vars/novo.yml`, `vars/serf.yml`, `vars/terminal.yml`, `vars/desktop.yml` are deleted with no new home (their hosts are no longer in active use per spec).

---

## Tasks

### Task 1: Scaffolding — ansible.cfg + empty ansible/ tree

**Files:**
- Create: `ansible.cfg`
- Create: `ansible/site.yml` (placeholder)
- Create: `ansible/playbooks/.gitkeep`
- Create: `ansible/inventory/hosts.yml` (initial empty inventory)
- Create: `ansible/group_vars/.gitkeep`
- Create: `ansible/host_vars/.gitkeep`
- Create: `ansible/roles/.gitkeep`
- Modify: `.gitignore` — add `*.retry` if not already present

**Note:** `ansible/inventory` currently exists as a 2-line file. We need to delete it before creating the directory.

- [ ] **Step 1: Remove the old 2-line ansible/inventory file**

```bash
git rm ansible/inventory
```

- [ ] **Step 2: Create ansible.cfg at repo root**

Write `ansible.cfg`:

```ini
[defaults]
inventory = ansible/inventory/hosts.yml
roles_path = ansible/roles
host_key_checking = False
forks = 10
timeout = 30
stdout_callback = ansible.builtin.default
callback_result_format = yaml
retry_files_enabled = False
gathering = smart

[privilege_escalation]
become = False
become_method = sudo
become_user = root
become_ask_pass = False

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=accept-new -o ForwardAgent=yes
pipelining = True
```

Rationale for `become = False` at the privilege-escalation default: most tasks in this repo run as the host user (dotfile symlinks). Server-side roles (`base`, `bootstrap`) declare `become: true` explicitly at the play or role level.

- [ ] **Step 3: Create directory skeleton**

```bash
mkdir -p ansible/playbooks ansible/inventory ansible/group_vars ansible/host_vars ansible/roles
touch ansible/playbooks/.gitkeep ansible/group_vars/.gitkeep ansible/host_vars/.gitkeep ansible/roles/.gitkeep
```

- [ ] **Step 4: Create placeholder ansible/site.yml**

Write `ansible/site.yml`:

```yaml
---
# Placeholder. Real orchestration written in Task 13.
- hosts: localhost
  connection: local
  tasks:
    - debug: msg="ansible/ scaffolding present; site.yml not yet implemented"
```

- [ ] **Step 5: Create initial inventory**

Write `ansible/inventory/hosts.yml`:

```yaml
---
all:
  hosts:
    localhost:
      ansible_connection: local
```

Registered remote hosts are added in Task 5.

- [ ] **Step 6: Verify scaffolding parses**

Run: `ansible-playbook ansible/site.yml --syntax-check`
Expected: `playbook: ansible/site.yml` (no errors).

Run: `ansible-inventory -i ansible/inventory/hosts.yml --list`
Expected: JSON output listing `localhost`.

Run (regression check — old playbook still works): `ansible-playbook general.yml --syntax-check`
Expected: `playbook: general.yml` (no errors).

- [ ] **Step 7: Commit**

```bash
git add ansible.cfg ansible/
git commit -m "ansible: scaffold ansible/ tree and root ansible.cfg

Begins the ansible restructure outlined in
docs/superpowers/specs/2026-05-19-ansible-restructure-design.md.
Old general.yml + tasks/ + vars/ layout remains functional; this
task only adds new structure."
```

---

### Task 2: Port global defaults to group_vars/all.yml

**Files:**
- Create: `ansible/group_vars/all.yml`
- Read: `defaults/main.yml` (source — not modified yet)

- [ ] **Step 1: Copy defaults/main.yml to group_vars/all.yml**

Write `ansible/group_vars/all.yml` with the exact content of today's `defaults/main.yml`. Verbatim copy is intentional — the rename + relocation alone is the step. Future deletions/extractions happen during role builds (Tasks 6–11).

```yaml
---
# Global defaults for all hosts. Ported from defaults/main.yml.

# git username of the repos to be pulled
git_username: fkarg
configs_repo: configs
dotconfigdir: dotconfig
todotxtrepo: gtd
finances_repo: finances

# username on this machine
username: pars

# computed home dir (linux vs macos)
home_dir: "{{ (ansible_facts['system'] == 'Darwin') | ternary('/Users','/home') }}/{{ username }}"

# cowfile on this machine
cowfile: default

# terminal for machine
terminal: kitty

# absolute path to background image to use for graphical systems. Default is one-screen.
background_image: "{{ home_dir }}/{{ configs_repo }}/pictures/IMAG7297.JPG"

# name of the audio sink
pactl_sink_name: 0

# git configs
git_email: f.karg10@gmail.com
git_name: Felix Karg
git_editor: nvim
git_difft: false
git_lfs: false

# ensure that nix is installed regardless of of the OS being nixOS
ensure_nix: true

# if nix is available, install a number of packages for the user
install_nix_programs: true

# shell integrations
direnv: false
zoxide: false

# broot file manager
enable_broot: false

repos_list:
  - "{{ home_dir }}/configs"
  - "{{ home_dir }}/text_zeug"
  - "{{ home_dir }}/Coding/lebenslauf"
  - "{{ home_dir }}/Coding/fkarg.github.io"
  - "{{ home_dir }}/Coding/beratervertrag"
  - "{{ home_dir }}/Coding/things-to-talk-about"

repos_additional: []
```

Note: `link_nixos` is **deleted here** — the `nixos_link` role is out of scope (per spec) and the variable has no consumers in the new layout.

- [ ] **Step 2: Verify group_vars loads correctly**

Run: `ansible -i ansible/inventory/hosts.yml localhost -m debug -a 'var=git_username'`
Expected: `"git_username": "fkarg"`.

Run: `ansible -i ansible/inventory/hosts.yml localhost -m debug -a 'var=enable_broot'`
Expected: `"enable_broot": false`.

- [ ] **Step 3: Commit**

```bash
git add ansible/group_vars/all.yml
git commit -m "ansible: port defaults/main.yml to group_vars/all.yml

Drops the unused link_nixos variable (nixos_link role is out of scope
for this restructure). Old defaults/main.yml stays in place until the
deletion task."
```

---

### Task 3: Port host_vars (active hosts: caeli, jolly, tux, artus, margo, hp440g5)

**Files:**
- Create: `ansible/host_vars/caeli.yml`
- Create: `ansible/host_vars/jolly.yml`
- Create: `ansible/host_vars/tux.yml`
- Create: `ansible/host_vars/artus.yml`
- Create: `ansible/host_vars/margo.yml`
- Create: `ansible/host_vars/hp440g5.yml`
- Read: `vars/caeli.yml`, `vars/jolly.yml`, etc. (sources — not modified)

The transformation rule for each: identity + machine vars from the old file go in as-is; **add** `host_roles:` list and (for non-local hosts) `ansible_user`/`ansible_port`/`ansible_host`.

- [ ] **Step 1: Create host_vars/caeli.yml**

Write `ansible/host_vars/caeli.yml`:

```yaml
---
# Personal Mac. No bootstrap/base — managed locally via ansible-pull.
ansible_connection: local
ansible_user: felix

host_roles:
  - terminal_dotfiles
  - os_macos
  - graphical_dotfiles
  - coding_agents

# identity
username: felix
cowfile: llama

# shell integrations
direnv: true
zoxide: true

# INVARIANT — Top-level only. (See spec for refresh procedure.)
# Both `brew_packages_common` and `brew_casks_common` below must list ONLY
# top-level (manually installed) packages, never transitive dependencies.
# Sources of truth: `brew leaves` and `brew list --cask` on the live host.

brew_packages_common:
  # shell, prompt & file utilities
  - bat
  - coreutils
  - cowsay
  - direnv
  - eza
  - fish
  - fortune
  - htop
  - ncdu
  - neofetch
  - ripgrep-all
  - watch
  - wget
  - yq
  - zoxide
  # editor, language servers & linters
  - languagetool
  - neovim
  - tinymist
  - yamllint
  # git & dev workflow
  - gh
  - git
  - git-filter-repo
  - glow
  - lazygit
  - tokei
  # programming languages & runtimes
  - ghc
  - node@24
  - oven-sh/bun/bun
  - pnpm
  - python-setuptools
  - rust
  - uv
  # containers & kubernetes
  - docker
  - docker-buildx
  - docker-compose
  - k3d
  - k9s
  - kubecfg
  - kubernetes-cli
  - kustomize
  # networking & remote access
  - iperf
  - ldns
  - mosh
  - nmap
  - socat
  - xpipe
  # storage & databases
  - minio-mc
  - postgresql@17
  # documents & typesetting
  - ghostscript
  - graphviz
  - psutils
  - qpdf
  - typst
  # finance / accounting
  - beancount
  - beancount-language-server
  - beanquery
  - fava
  # infrastructure / config management
  - ansible
  - ansible-language-server
  - ansible-lint
  # AI / coding agents
  - ccusage
  - gemini-cli
  - opencode
  # macOS-specific helpers
  - batt
  - sleepwatcher
brew_packages_extra: []

brew_casks_common:
  # window management & system tweaks
  - amethyst
  - caffeine
  - hammerspoon
  - karabiner-elements
  - logi-options+
  - raycast
  - rectangle
  - scroll-reverser
  - stats
  # terminals & editors
  - kitty
  - visual-studio-code
  # browsers
  - firefox
  - google-chrome
  - tor-browser
  # communication & messaging
  - betterdiscord-installer
  - discord
  - microsoft-teams
  - signal
  - telegram
  - telegram-desktop
  - whatsapp
  # proton suite
  - proton-drive
  - proton-mail
  - proton-pass
  - protonvpn
  # microsoft office
  - microsoft-excel
  - microsoft-outlook
  - microsoft-powerpoint
  - microsoft-word
  # productivity & documents
  - libreoffice
  - obsidian
  # AI / coding agents
  - claude-code
  - codex
  - comfyui
  - copilot-cli
  - ollama-app
  - wispr-flow
  # containers & virtualization
  - docker-desktop
  - utm
  # media
  - vlc
  - yt-music
brew_casks_extra: []
```

- [ ] **Step 2: Create host_vars/jolly.yml**

Write `ansible/host_vars/jolly.yml`:

```yaml
---
# Desktop NixOS tower. Managed locally via ansible-pull.
ansible_connection: local
ansible_user: pars
ansible_port: 22

host_roles:
  - terminal_dotfiles
  - graphical_dotfiles
  - coding_agents

# identity
username: pars
cowfile: default

# network interfaces
lan: enp10s0

# no battery (desktop)
battery: false

# USB audio DAC (main output)
pactl_sink_name: alsa_output.usb-Generic_USB_Audio-00.HiFi__Speaker__sink

background_image: "{{ home_dir }}/{{ configs_repo }}/pictures/IMAG7297.JPG"
```

Note: jolly's `link_nixos: true` and `nixos_state_version` are intentionally dropped (`nixos_link` role out of scope). `base` is also omitted because NixOS hosts handle base concerns (firewall, packages, swap) declaratively in `nixos/` config, not via apt.

- [ ] **Step 3: Create host_vars/tux.yml**

Write `ansible/host_vars/tux.yml`:

```yaml
---
ansible_connection: local
ansible_user: pars

host_roles:
  - terminal_dotfiles
  - graphical_dotfiles
  - coding_agents

username: pars
cowfile: tux
lan: enp3s0f1
wifi: wlp2s0
battery: true
pactl_sink_name: alsa_output.pci-0000_00_1f.3.analog-stereo

repos_additional:
  - "/home/$USER/Coding/heliopas-waterfox-backend"
  - "/home/$USER/Coding/heliopas-waterfox-app"
```

- [ ] **Step 4: Create host_vars/artus.yml**

Write `ansible/host_vars/artus.yml`:

```yaml
---
ansible_connection: local
ansible_user: pars

host_roles:
  - terminal_dotfiles
  - graphical_dotfiles
  - coding_agents

username: pars
cowfile: default
battery: true
```

Note: source `vars/artus.yml` is sparse; identity inherits from `group_vars/all.yml`.

- [ ] **Step 5: Create host_vars/margo.yml**

Write `ansible/host_vars/margo.yml`:

```yaml
---
ansible_connection: local
ansible_user: pars

host_roles:
  - terminal_dotfiles
  - graphical_dotfiles
  - coding_agents

username: pars
cowfile: default
battery: true
```

- [ ] **Step 6: Create host_vars/hp440g5.yml**

Write `ansible/host_vars/hp440g5.yml`:

```yaml
---
ansible_connection: local
ansible_user: pars

host_roles:
  - terminal_dotfiles
  - graphical_dotfiles
  - coding_agents

username: pars
cowfile: default
lan: enp0s31f6
wifi: wlp1s0
battery: true
```

- [ ] **Step 7: Verify host_vars load**

Run: `ansible -i ansible/inventory/hosts.yml caeli -m debug -a 'var=host_roles' 2>&1 | head -10` — but caeli isn't in inventory yet. Skip the inventory-bound check until Task 4.

Instead verify per-host with an explicit lookup:

```bash
ansible-playbook ansible/site.yml -e host_id=caeli --tags none --check 2>&1 | grep -i 'caeli\|host_roles\|brew_packages' || true
```

(`--tags none` matches nothing, so this just exercises var loading without running tasks. Site.yml is still a placeholder, so this primarily exercises file presence.)

A more direct verification — for each host_vars file, run YAML lint:

```bash
for f in ansible/host_vars/*.yml; do python3 -c "import yaml; yaml.safe_load(open('$f'))" && echo "OK: $f"; done
```

Expected: `OK: ansible/host_vars/<each>.yml` for all six files.

- [ ] **Step 8: Commit**

```bash
git add ansible/host_vars/
git commit -m "ansible: port active host_vars (caeli, jolly, tux, artus, margo, hp440g5)

Each file declares ansible connection identity, machine-specific
knobs, and a host_roles list. Inactive vars/ entries (snb, novo,
serf, terminal, desktop) are NOT ported and will be deleted in the
cleanup task. NixOS-specific vars (link_nixos, nixos_state_version)
are dropped since the nixos_link role is out of scope."
```

---

### Task 4: Update inventory to register active hosts

**Files:**
- Modify: `ansible/inventory/hosts.yml`

- [ ] **Step 1: Replace placeholder inventory with active host list**

Write `ansible/inventory/hosts.yml`:

```yaml
---
# Static inventory for push-mode ansible-playbook runs from a workstation.
# Pull-mode (ansible-pull on the host itself) does not consult this file —
# it resolves host_vars via -e host_id=<name> or inventory_hostname=localhost.
#
# To add a new host:
#   1. Create ansible/host_vars/<name>.yml with host_roles + identity.
#   2. Add an entry below under the appropriate group.
#
all:
  children:
    personal:
      hosts:
        caeli:
          ansible_connection: local
        jolly:
          ansible_connection: local
        tux:
          ansible_connection: local
        artus:
          ansible_connection: local
        margo:
          ansible_connection: local
        hp440g5:
          ansible_connection: local
    # remote hosts (servers, VMs) get registered here when added:
    # servers:
    #   hosts:
    #     hetzner-vm-1:
    #       ansible_host: 1.2.3.4
```

- [ ] **Step 2: Verify inventory parses and resolves host_vars**

Run: `ansible-inventory -i ansible/inventory/hosts.yml --list`
Expected: JSON containing each personal host with `ansible_connection: local`.

Run: `ansible-inventory -i ansible/inventory/hosts.yml --host caeli`
Expected: JSON containing `host_roles`, `username: felix`, `brew_packages_common: [...]`.

- [ ] **Step 3: Commit**

```bash
git add ansible/inventory/hosts.yml
git commit -m "ansible: register active hosts in inventory/hosts.yml

All six active personal machines under a 'personal' group with
ansible_connection: local. Remote-server group commented out as
a template for when the first hetzner VM joins."
```

---

### Task 5: Build `coding_agents` role (smallest, lowest-risk port)

**Files:**
- Create: `ansible/roles/coding_agents/tasks/main.yml`
- Create: `ansible/roles/coding_agents/defaults/main.yml`
- Read: `tasks/coding_agents.yml` (source — not modified)

This is the easiest port: a single task file with no dependencies on `vars/`, `defaults/`, or templates. The only transformation: `playbook_dir` references become `role_path`-relative.

Wait — actually the existing `tasks/coding_agents.yml` uses `{{ playbook_dir }}/coding-agents/...`. The `coding-agents/` source dir is at the repo root, not inside the role. So the role needs to reference it via `playbook_dir` (which resolves to `ansible/` when run via `site.yml`), or via an absolute path resolved at task time.

Use `playbook_dir | dirname` to get to the repo root (since `playbook_dir` is `<repo>/ansible`). That stays correct regardless of which entry playbook is used (`site.yml`, `playbooks/bootstrap.yml`, `playbooks/terminal.yml`), since all live under `ansible/`. For `playbooks/*.yml`, `playbook_dir` is `<repo>/ansible/playbooks` — so we need a more robust resolution.

Cleanest fix: declare a group-wide `repo_root` variable.

- [ ] **Step 1: Add repo_root to group_vars/all.yml**

Append to `ansible/group_vars/all.yml`:

```yaml

# Repo root — resolves whether the entry playbook is ansible/site.yml or
# ansible/playbooks/*.yml. Used by tasks that need to reference files
# outside the ansible/ tree (e.g. coding-agents/build.py).
repo_root: "{{ playbook_dir | regex_replace('/playbooks$', '') | regex_replace('/ansible$', '') }}"
```

- [ ] **Step 2: Write coding_agents defaults**

Write `ansible/roles/coding_agents/defaults/main.yml`:

```yaml
---
coding_agents_source_dir: "{{ repo_root }}/coding-agents"
coding_agents_build_script: "{{ coding_agents_source_dir }}/build.py"
```

- [ ] **Step 3: Write coding_agents tasks**

Write `ansible/roles/coding_agents/tasks/main.yml`:

```yaml
---
# Sync shared coding-agent / subagent definitions across tools.
# Canonical source: <repo>/coding-agents/source/<name>.md
# build.py renders per-tool variants under coding-agents/generated/.

- name: Ensure global agent directories exist
  file:
    path: "{{ item }}"
    state: directory
  loop:
    - "~/.config/opencode/agents"
    - "~/.claude/agents"
    - "~/.codex/agents"
    - "~/.copilot/agents"

- name: Build per-tool agent variants from canonical source
  command:
    cmd: python3 build.py
    chdir: "{{ coding_agents_source_dir }}"
  changed_when: false

- name: Discover canonical source agents
  find:
    paths: "{{ coding_agents_source_dir }}/source"
    patterns: "*.md"
  register: ca_sources

- name: Symlink OpenCode agents (canonical format, no transform)
  file:
    src: "{{ item.path }}"
    dest: "~/.config/opencode/agents/{{ item.path | basename }}"
    state: link
    force: true
  loop: "{{ ca_sources.files }}"
  loop_control:
    label: "{{ item.path | basename }}"

- name: Discover generated Claude Code agents
  find:
    paths: "{{ coding_agents_source_dir }}/generated/claude/agents"
    patterns: "*.md"
  register: ca_claude

- name: Symlink Claude Code agents
  file:
    src: "{{ item.path }}"
    dest: "~/.claude/agents/{{ item.path | basename }}"
    state: link
    force: true
  loop: "{{ ca_claude.files }}"
  loop_control:
    label: "{{ item.path | basename }}"

- name: Discover generated Codex agents
  find:
    paths: "{{ coding_agents_source_dir }}/generated/codex/agents"
    patterns: "*.toml"
  register: ca_codex

- name: Symlink Codex agents
  file:
    src: "{{ item.path }}"
    dest: "~/.codex/agents/{{ item.path | basename }}"
    state: link
    force: true
  loop: "{{ ca_codex.files }}"
  loop_control:
    label: "{{ item.path | basename }}"

- name: Discover generated Copilot CLI agents
  find:
    paths: "{{ coding_agents_source_dir }}/generated/copilot/agents"
    patterns: "*.agent.md"
  register: ca_copilot

- name: Symlink Copilot CLI agents
  file:
    src: "{{ item.path }}"
    dest: "~/.copilot/agents/{{ item.path | basename }}"
    state: link
    force: true
  loop: "{{ ca_copilot.files }}"
  loop_control:
    label: "{{ item.path | basename }}"
```

Note: the `tags: [coding-agents]` from the original are intentionally **not** repeated at each task — the role tag is applied automatically by `site.yml`'s `include_role`. Per-task concern tags inside this role aren't needed since there are no cross-cutting concerns; the whole role is one concern.

- [ ] **Step 4: Write a tiny verification playbook**

Write `ansible/playbooks/_test_coding_agents.yml` (temporary; deleted before merge of Task 13):

```yaml
---
- hosts: localhost
  connection: local
  gather_facts: true
  roles:
    - coding_agents
```

- [ ] **Step 5: Syntax-check the role**

Run: `ansible-playbook ansible/playbooks/_test_coding_agents.yml --syntax-check`
Expected: `playbook: ansible/playbooks/_test_coding_agents.yml`.

- [ ] **Step 6: Check-mode run against caeli (local Mac)**

Run: `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/_test_coding_agents.yml -l caeli --check --diff`
Expected: green run, "ok=N changed=0" — because the existing setup already has these symlinks in place. If "changed > 0" appears for the `Build per-tool agent variants` task, that's expected (it's marked `changed_when: false` so it shouldn't even show as changed).

If anything shows "changed" beyond the python build step, investigate before proceeding — there's a divergence between the new role and what the old `tasks/coding_agents.yml` already produced.

- [ ] **Step 7: Delete the temp verification playbook**

```bash
rm ansible/playbooks/_test_coding_agents.yml
```

- [ ] **Step 8: Commit**

```bash
git add ansible/roles/coding_agents/ ansible/group_vars/all.yml
git commit -m "ansible: add coding_agents role

Verbatim port of tasks/coding_agents.yml with one cosmetic change:
references to coding-agents/ via {{ playbook_dir }} are replaced with
{{ repo_root }} (resolved in group_vars/all.yml) so the role works
identically whether invoked from ansible/site.yml or
ansible/playbooks/*.yml. Old tasks/coding_agents.yml remains in place
until the cleanup task."
```

---

### Task 6: Build `terminal_dotfiles` role (with shared link_dotdir helper)

**Files:**
- Create: `ansible/roles/terminal_dotfiles/tasks/main.yml`
- Create: `ansible/roles/terminal_dotfiles/tasks/link_dotdir.yml`
- Create: `ansible/roles/terminal_dotfiles/defaults/main.yml`
- Create: `ansible/roles/terminal_dotfiles/handlers/main.yml`
- Create: `ansible/roles/terminal_dotfiles/templates/gitconfig.j2` (copy of existing `templates/gitconfig.j2`)
- Create: `ansible/roles/terminal_dotfiles/templates/fishconfig.j2` (copy of existing `templates/fishconfig.j2`)
- Read: `tasks/terminal.yml`, `templates/gitconfig.j2`, `templates/fishconfig.j2`, `handlers/main.yml` (sources)

- [ ] **Step 1: Copy templates**

```bash
cp templates/gitconfig.j2 ansible/roles/terminal_dotfiles/templates/gitconfig.j2
cp templates/fishconfig.j2 ansible/roles/terminal_dotfiles/templates/fishconfig.j2
mkdir -p ansible/roles/terminal_dotfiles/{tasks,defaults,handlers}
```

- [ ] **Step 2: Write the shared link_dotdir helper**

Write `ansible/roles/terminal_dotfiles/tasks/link_dotdir.yml`:

```yaml
---
# Reusable "stat → optionally remove → symlink" helper.
# Inputs:
#   link_src   — subpath under {{ dotconfigdir }} in the configs repo
#   link_dest  — target path (e.g. ~/.config/fish)
# Behavior:
#   - If link_dest is a real directory and confirm_overwrite is true and we're
#     not in check mode: remove it.
#   - Otherwise, if it's a real directory and we're not in check mode: skip
#     the symlink to preserve user data (matches existing safety behavior).
#   - Otherwise: create/refresh the symlink.

- name: "link_dotdir: stat {{ link_dest }}"
  stat:
    path: "{{ link_dest }}"
  register: _ld_stat

- name: "link_dotdir: remove existing real dir {{ link_dest }} (confirm_overwrite=true)"
  file:
    path: "{{ link_dest }}"
    state: absent
  when:
    - _ld_stat.stat.exists
    - _ld_stat.stat.isdir | default(false)
    - not (_ld_stat.stat.islnk | default(false))
    - confirm_overwrite | default(false) | bool
    - not ansible_check_mode

- name: "link_dotdir: symlink {{ link_dest }} -> ~/{{ configs_repo }}/{{ dotconfigdir }}/{{ link_src }}"
  file:
    src: "~/{{ configs_repo }}/{{ dotconfigdir }}/{{ link_src }}"
    dest: "{{ link_dest }}"
    state: link
  when: >
    not (_ld_stat.stat.exists and _ld_stat.stat.isdir | default(false)
         and not (_ld_stat.stat.islnk | default(false))
         and not (confirm_overwrite | default(false) | bool))
```

- [ ] **Step 3: Write defaults**

Write `ansible/roles/terminal_dotfiles/defaults/main.yml`:

```yaml
---
# Toggled from host_vars or group_vars.
enable_broot: false
confirm_overwrite: false
```

- [ ] **Step 4: Write handlers**

Write `ansible/roles/terminal_dotfiles/handlers/main.yml`:

```yaml
---
- name: Create local broot links
  shell: broot --install
  listen: "install br"
  when: enable_broot | default(false) | bool
```

- [ ] **Step 5: Write main tasks**

Write `ansible/roles/terminal_dotfiles/tasks/main.yml`:

```yaml
---
# Base profile installation: repo clone, gitconfig, fish, nvim/vim, optionally
# broot, text_zeug clone. Runs on every host.

# ============================================
# CONFIGS REPO PRESENCE
# ============================================
- name: Check if .ssh key present
  stat:
    path: ~/.ssh/id_rsa.pub
  register: _ssh
  tags: [repos, always]

- name: Make sure ~/configs/ is present (via SSH)
  git:
    repo: "git@github.com:{{ git_username }}/{{ configs_repo }}.git"
    dest: "~/{{ configs_repo }}"
    accept_hostkey: true
    update: no
  register: _repo
  when: _ssh is succeeded and _ssh.stat.exists
  tags: [repos]

- name: Make sure ~/configs/ is present (via HTTPS fallback)
  git:
    repo: "https://github.com/{{ git_username }}/{{ configs_repo }}.git"
    dest: "~/{{ configs_repo }}"
    accept_hostkey: true
    update: no
  register: _repo
  when: not (_ssh.stat.exists | default(false))
  tags: [repos]

- name: Update ~/configs/ repository
  git:
    repo: "git@github.com:{{ git_username }}/{{ configs_repo }}.git"
    dest: "~/{{ configs_repo }}"
  when: _repo is succeeded and _ssh.stat.exists
  ignore_errors: true
  tags: [repos]

# ============================================
# GIT CONFIG
# ============================================
- name: Template .gitconfig
  template:
    src: gitconfig.j2
    dest: ~/.gitconfig
  tags: [git]

# ============================================
# FISH
# ============================================
- include_tasks: link_dotdir.yml
  vars: { link_src: fish, link_dest: ~/.config/fish }
  tags: [fish]

- name: Template fish config
  template:
    src: fishconfig.j2
    dest: ~/.config/fish/config.fish
  notify: "install br"
  when: enable_broot | default(false) | bool
  tags: [fish]

- name: Template fish config (broot disabled)
  template:
    src: fishconfig.j2
    dest: ~/.config/fish/config.fish
  when: not (enable_broot | default(false) | bool)
  tags: [fish]

# ============================================
# NVIM + VIM
# ============================================
- name: Create nvim plugin directory
  file:
    path: ~/.config/nvimplugins
    state: directory
  tags: [nvim]

- include_tasks: link_dotdir.yml
  vars: { link_src: nvim, link_dest: ~/.config/nvim }
  tags: [nvim]

- include_tasks: link_dotdir.yml
  vars: { link_src: nvim, link_dest: ~/.config/vim }
  tags: [nvim]

# ============================================
# TEXT_ZEUG
# ============================================
- name: Make sure text_zeug is present
  git:
    repo: "git@github.com:{{ git_username }}/text_zeug.git"
    dest: ~/text_zeug
    update: no
  when: _ssh.stat.exists | default(false)
  ignore_errors: true
  tags: [repos]
```

Note: the `~/.local/bin/b` symlink and broot install from the original `terminal.yml` are intentionally moved to `graphical_dotfiles` (alongside the broot config symlink), since broot is a GUI-relevant tool per the spec discussion.

- [ ] **Step 6: Write a temporary verification playbook**

Write `ansible/playbooks/_test_terminal.yml`:

```yaml
---
- hosts: localhost
  connection: local
  gather_facts: true
  roles:
    - terminal_dotfiles
```

- [ ] **Step 7: Syntax-check the role**

Run: `ansible-playbook ansible/playbooks/_test_terminal.yml --syntax-check`
Expected: `playbook: ansible/playbooks/_test_terminal.yml`.

- [ ] **Step 8: Check-mode against caeli**

Run: `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/_test_terminal.yml -l caeli --check --diff`
Expected: `changed=0` (everything already in place from the old playbook). If any of the symlinks show "changed", the helper's `when:` differs from the old open-coded version — investigate.

- [ ] **Step 9: Delete temp playbook**

```bash
rm ansible/playbooks/_test_terminal.yml
```

- [ ] **Step 10: Commit**

```bash
git add ansible/roles/terminal_dotfiles/
git commit -m "ansible: add terminal_dotfiles role

Includes a reusable link_dotdir.yml helper that consolidates the
stat→remove→symlink pattern previously open-coded 5+ times in
tasks/terminal.yml and tasks/configs_graphical.yml. Concern tags
(git, fish, nvim, repos) added per task. Broot's ~/.local/bin/b
symlink moves to graphical_dotfiles in the next task."
```

---

### Task 7: Build `graphical_dotfiles` role

**Files:**
- Create: `ansible/roles/graphical_dotfiles/tasks/main.yml`
- Create: `ansible/roles/graphical_dotfiles/handlers/main.yml`
- Create: `ansible/roles/graphical_dotfiles/templates/i3config.j2` (copy)
- Create: `ansible/roles/graphical_dotfiles/templates/i3statusconfig.j2` (copy)
- Create: `ansible/roles/graphical_dotfiles/templates/on_startup.j2` (copy)
- Create: `ansible/roles/graphical_dotfiles/templates/todoconfig.j2` (copy)
- Read: `tasks/configs_graphical.yml`, `handlers/main.yml` (sources)

- [ ] **Step 1: Copy templates**

```bash
mkdir -p ansible/roles/graphical_dotfiles/{tasks,handlers,templates}
cp templates/i3config.j2 ansible/roles/graphical_dotfiles/templates/i3config.j2
cp templates/i3statusconfig.j2 ansible/roles/graphical_dotfiles/templates/i3statusconfig.j2
cp templates/on_startup.j2 ansible/roles/graphical_dotfiles/templates/on_startup.j2
cp templates/todoconfig.j2 ansible/roles/graphical_dotfiles/templates/todoconfig.j2
```

- [ ] **Step 2: Write handlers**

Write `ansible/roles/graphical_dotfiles/handlers/main.yml`:

```yaml
---
- name: Restart i3 with new config
  shell: i3 restart
  register: _result
  failed_when: "'[{\"success\":true}]' not in _result.stdout or 'Sending them as a command to i3' not in _result.stdout"
  listen: "restart i3"
```

- [ ] **Step 3: Write main tasks**

Write `ansible/roles/graphical_dotfiles/tasks/main.yml`:

```yaml
---
# Graphical-host dotfiles: kitty, hyprland, i3, broot, fonts, background,
# todo, gtd/finances repos. Most tasks are Linux-only (i3, hyprland, fonts);
# kitty is cross-platform. Each tool has a concern tag.

# ============================================
# I3 (Linux only)
# ============================================
- name: Create config/i3 directory
  file:
    path: ~/.config/i3
    state: directory
  when: ansible_facts['system'] == 'Linux'
  tags: [i3]

- name: Template on_startup.sh
  template:
    src: on_startup.j2
    dest: ~/on_startup.sh
    mode: '0500'
  notify: "restart i3"
  when: ansible_facts['system'] == 'Linux'
  tags: [i3]

- name: Template i3 config
  template:
    src: i3config.j2
    dest: ~/.config/i3/config
  notify: "restart i3"
  when: ansible_facts['system'] == 'Linux'
  tags: [i3]

- name: Create config/i3status directory
  file:
    path: ~/.config/i3status
    state: directory
  when: ansible_facts['system'] == 'Linux'
  tags: [i3]

- name: Template i3status config
  template:
    src: i3statusconfig.j2
    dest: ~/.config/i3status/config.toml
  notify: "restart i3"
  when: ansible_facts['system'] == 'Linux'
  tags: [i3]

# ============================================
# KITTY (cross-platform)
# ============================================
- include_role:
    name: terminal_dotfiles
    tasks_from: link_dotdir
  vars: { link_src: kitty, link_dest: ~/.config/kitty }
  when: terminal == "kitty"
  tags: [kitty]

# ============================================
# HYPRLAND (Linux only)
# ============================================
- name: Ensure hypr config directory exists
  file:
    path: ~/.config/hypr
    state: directory
  when: ansible_facts['system'] == 'Linux'
  tags: [hyprland]

- name: Check if hyprland.conf is already a symlink
  stat:
    path: ~/.config/hypr/hyprland.conf
  register: _hyprland_conf
  when: ansible_facts['system'] == 'Linux'
  tags: [hyprland]

- name: Remove existing hyprland.conf file (confirm_overwrite=true)
  file:
    path: ~/.config/hypr/hyprland.conf
    state: absent
  when:
    - ansible_facts['system'] == 'Linux'
    - _hyprland_conf.stat.exists | default(false)
    - not (_hyprland_conf.stat.islnk | default(false))
    - confirm_overwrite | default(false) | bool
    - not ansible_check_mode
  tags: [hyprland]

- name: Link hyprland config file
  file:
    src: "~/{{ configs_repo }}/{{ dotconfigdir }}/hypr/hyprland.conf"
    dest: ~/.config/hypr/hyprland.conf
    state: link
  when:
    - ansible_facts['system'] == 'Linux'
    - not (_hyprland_conf.stat.exists | default(false) and not (_hyprland_conf.stat.islnk | default(false)) and not (confirm_overwrite | default(false) | bool))
  tags: [hyprland]

# ============================================
# FIREFOX LEGACY PATH (Linux only)
# ============================================
- name: Check legacy Mozilla Firefox path
  stat:
    path: ~/.mozilla/firefox
  register: _moz_firefox
  when: ansible_facts['system'] == 'Linux'
  tags: [firefox]

- name: Ensure legacy Mozilla directory exists
  file:
    path: ~/.mozilla
    state: directory
  when: ansible_facts['system'] == 'Linux'
  tags: [firefox]

- name: Link legacy Firefox profile path to XDG location
  file:
    src: ~/.config/mozilla/firefox
    dest: ~/.mozilla/firefox
    state: link
  when:
    - ansible_facts['system'] == 'Linux'
    - not (_moz_firefox.stat.exists | default(false) and not (_moz_firefox.stat.islnk | default(false)) and not (confirm_overwrite | default(false) | bool))
  tags: [firefox]

# ============================================
# BACKGROUND PICTURE
# ============================================
- name: Create folder for background picture
  file:
    path: ~/Pictures/Space
    state: directory
  tags: [background]

- name: Copy initial background picture
  copy:
    src: "~/{{ configs_repo }}/pictures/IMAG7297.JPG"
    dest: "~/Pictures/Space/IMAG7297.JPG"
  tags: [background]

# ============================================
# TODO
# ============================================
- name: Create todo.sh config dir
  file:
    path: ~/.config/todo
    state: directory
  tags: [todo]

- name: Template todo.sh config
  template:
    src: todoconfig.j2
    dest: ~/.config/todo/config
  tags: [todo]

- name: Create empty todo.sh actions file
  copy:
    content: ""
    dest: ~/.config/todo/actions
    force: no
  tags: [todo]

- name: Make sure gtd repository is present
  git:
    repo: "git@github.com:{{ git_username }}/{{ todotxtrepo }}.git"
    dest: "~/{{ todotxtrepo }}"
    update: yes
  ignore_errors: true
  tags: [todo, repos]

# ============================================
# FINANCES
# ============================================
- name: Make sure finances repository is present
  git:
    repo: "git@github.com:{{ git_username }}/{{ finances_repo }}.git"
    dest: "~/{{ finances_repo }}"
    update: yes
  ignore_errors: true
  tags: [repos]

# ============================================
# FONTS (Linux only)
# ============================================
- name: Create fonts directory
  file:
    path: ~/.local/share/fonts
    state: directory
  when: ansible_facts['system'] == 'Linux'
  tags: [fonts]

- name: Unarchive Fontin font
  ansible.builtin.unarchive:
    src: https://wfonts.com/download/data/2015/03/10/fontin/fontin.zip
    dest: ~/.local/share/fonts
    remote_src: yes
  when: ansible_facts['system'] == 'Linux'
  ignore_errors: true
  tags: [fonts]

- name: Duplicate Regular Fontin File
  copy:
    src: ~/.local/share/fonts/Fontin-Regular.otf
    dest: ~/.local/share/fonts/Fontin.otf
    mode: '0644'
  ignore_errors: true
  when: ansible_facts['system'] == 'Linux'
  tags: [fonts]

# ============================================
# BROOT (cross-platform, gated by enable_broot)
# ============================================
- include_role:
    name: terminal_dotfiles
    tasks_from: link_dotdir
  vars: { link_src: broot, link_dest: ~/.config/broot }
  when: enable_broot | default(false) | bool
  tags: [broot]

- name: Create .local/bin
  file:
    path: ~/.local/bin
    state: directory
  when: enable_broot | default(false) | bool
  tags: [broot]

- name: Link broot launcher script
  file:
    src: "~/{{ configs_repo }}/scripts/b.sh"
    dest: ~/.local/bin/b
    state: link
  when: enable_broot | default(false) | bool
  tags: [broot]
```

Note on the kitty include: the original `tasks/configs_graphical.yml` gated kitty linking on `terminal == "kitty"` only — no Linux/macOS gate. That's preserved here so the link works on caeli too.

- [ ] **Step 4: Write a temp verification playbook**

Write `ansible/playbooks/_test_graphical.yml`:

```yaml
---
- hosts: localhost
  connection: local
  gather_facts: true
  roles:
    - graphical_dotfiles
```

- [ ] **Step 5: Syntax-check**

Run: `ansible-playbook ansible/playbooks/_test_graphical.yml --syntax-check`
Expected: clean.

- [ ] **Step 6: Check-mode against caeli (macOS — exercises kitty, background, todo, finances paths)**

Run: `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/_test_graphical.yml -l caeli --check --diff`
Expected: `changed=0` on the kitty/todo/background paths (already in place from old playbook). Linux-only tasks (i3, hyprland, fonts) should be skipped with `system != 'Darwin'`.

- [ ] **Step 7: Delete temp playbook**

```bash
rm ansible/playbooks/_test_graphical.yml
```

- [ ] **Step 8: Commit**

```bash
git add ansible/roles/graphical_dotfiles/
git commit -m "ansible: add graphical_dotfiles role

Ports tasks/configs_graphical.yml. Kitty and broot symlinks use the
link_dotdir helper from terminal_dotfiles via include_role +
tasks_from. Concern tags (i3, kitty, hyprland, broot, todo, fonts,
background, firefox, repos) added per task block."
```

---

### Task 8: Build `os_macos` role

**Files:**
- Create: `ansible/roles/os_macos/tasks/main.yml`
- Create: `ansible/roles/os_macos/tasks/packages.yml`
- Create: `ansible/roles/os_macos/tasks/autoupdates.yml`
- Create: `ansible/roles/os_macos/defaults/main.yml`
- Read: `tasks/macos_packages.yml`, `tasks/macos_disable_autoupdates.yml` (sources)

- [ ] **Step 1: Write defaults**

Write `ansible/roles/os_macos/defaults/main.yml`:

```yaml
---
# All brew lists default to empty here; populated in host_vars/<host>.yml.
brew_packages_common: []
brew_packages_extra: []
brew_casks_common: []
brew_casks_extra: []
```

- [ ] **Step 2: Write packages.yml**

Write `ansible/roles/os_macos/tasks/packages.yml`:

```yaml
---
- name: Detect existing brew (Apple Silicon)
  stat:
    path: /opt/homebrew/bin/brew
  register: _brew_opt

- name: Detect existing brew (Intel)
  stat:
    path: /usr/local/bin/brew
  register: _brew_usr

- name: Install Homebrew
  shell: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  when: not _brew_opt.stat.exists and not _brew_usr.stat.exists

- name: Set brew_bin fact
  set_fact:
    brew_bin: >-
      {{ '/opt/homebrew/bin/brew' if _brew_opt.stat.exists else (
           '/usr/local/bin/brew' if _brew_usr.stat.exists else '/opt/homebrew/bin/brew') }}

- name: Install brew formulae
  community.general.homebrew:
    name: "{{ item }}"
    state: present
    path: "{{ brew_bin | dirname }}"
  loop: "{{ (brew_packages_common | default([])) + (brew_packages_extra | default([])) }}"
  tags: [brew_formulae]

- name: Install brew casks
  community.general.homebrew_cask:
    name: "{{ item }}"
    state: present
    path: "{{ brew_bin | dirname }}"
    greedy: true
  loop: "{{ (brew_casks_common | default([])) + (brew_casks_extra | default([])) }}"
  ignore_errors: true
  tags: [brew_casks]
```

- [ ] **Step 3: Write autoupdates.yml**

Write `ansible/roles/os_macos/tasks/autoupdates.yml`:

```yaml
---
# Disable in-app auto-update mechanisms so Homebrew remains source of truth.

- name: Disable Sparkle auto-update checks
  community.general.osx_defaults:
    domain: "{{ item.domain }}"
    key: "{{ item.key }}"
    type: bool
    value: false
    state: present
  loop:
    - { domain: com.amethyst.Amethyst,        key: SUEnableAutomaticChecks }
    - { domain: com.amethyst.Amethyst,        key: SUAutomaticallyUpdate }
    - { domain: org.hammerspoon.Hammerspoon,  key: SUEnableAutomaticChecks }
    - { domain: org.hammerspoon.Hammerspoon,  key: SUAutomaticallyUpdate }
    - { domain: com.knollsoft.Rectangle,      key: SUEnableAutomaticChecks }
    - { domain: com.knollsoft.Rectangle,      key: SUAutomaticallyUpdate }
    - { domain: eu.exelban.Stats,             key: SUEnableAutomaticChecks }
    - { domain: eu.exelban.Stats,             key: SUAutomaticallyUpdate }
    - { domain: org.videolan.vlc,             key: SUEnableAutomaticChecks }
    - { domain: org.videolan.vlc,             key: SUAutomaticallyUpdate }

- name: Disable Microsoft AutoUpdate (Excel, Word, PowerPoint, Outlook, Teams)
  community.general.osx_defaults:
    domain: com.microsoft.autoupdate2
    key: HowToCheck
    type: string
    value: Manual
    state: present

- name: Disable Microsoft AutoUpdate automatic download
  community.general.osx_defaults:
    domain: com.microsoft.autoupdate2
    key: AutomaticDownload
    type: bool
    value: false
    state: present

- name: Disable Google Keystone (Chrome) update checks
  community.general.osx_defaults:
    domain: com.google.Keystone.Agent
    key: checkInterval
    type: float
    value: 0
    state: present
```

- [ ] **Step 4: Write main.yml**

Write `ansible/roles/os_macos/tasks/main.yml`:

```yaml
---
# All tasks gated by Darwin at the include level.
- include_tasks: packages.yml
  when: ansible_facts['system'] == 'Darwin'
  tags: [brew_formulae, brew_casks]

- include_tasks: autoupdates.yml
  when: ansible_facts['system'] == 'Darwin'
  tags: [autoupdates]
```

- [ ] **Step 5: Temp verification playbook**

Write `ansible/playbooks/_test_macos.yml`:

```yaml
---
- hosts: localhost
  connection: local
  gather_facts: true
  roles:
    - os_macos
```

- [ ] **Step 6: Syntax-check**

Run: `ansible-playbook ansible/playbooks/_test_macos.yml --syntax-check`
Expected: clean.

- [ ] **Step 7: Check-mode against caeli**

Run: `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/_test_macos.yml -l caeli --check --diff`
Expected: brew formulae/casks idempotent (`changed=0` for installed items); osx_defaults `changed=0` if already set previously.

- [ ] **Step 8: Delete temp playbook**

```bash
rm ansible/playbooks/_test_macos.yml
```

- [ ] **Step 9: Commit**

```bash
git add ansible/roles/os_macos/
git commit -m "ansible: add os_macos role

Splits brew install/packages and autoupdate-disable into two task
files for clarity. Both gated by Darwin at the include level so the
role compiles fine on Linux hosts (where it would never be in
host_roles anyway). Defaults list empty brew arrays; real lists live
in host_vars/caeli.yml."
```

---

### Task 9: Build `base` role

**Files:**
- Create: `ansible/roles/base/tasks/main.yml`
- Create: `ansible/roles/base/tasks/cron.yml`
- Create: `ansible/roles/base/defaults/main.yml`
- Create: `ansible/roles/base/handlers/main.yml`
- Create: `ansible/roles/base/templates/passive_update.j2` (copy of existing)
- Read: `~/Coding/infrastructure/ansible/roles/base/` (reference), `tasks/terminal_extended.yml`, `templates/passive_update.j2` (sources)

`base` is server-only — runs after `bootstrap`, before dotfile roles, on Debian/Ubuntu Linux servers. None of the current personal hosts (which are NixOS or macOS) use it directly; it's primarily for future Hetzner-style VMs. Build it pragmatically derived from the infra repo's base, trimmed to the subset relevant for terminal-only VMs.

- [ ] **Step 1: Copy passive_update template**

```bash
mkdir -p ansible/roles/base/{tasks,defaults,handlers,templates}
cp templates/passive_update.j2 ansible/roles/base/templates/passive_update.j2
```

- [ ] **Step 2: Write defaults**

Write `ansible/roles/base/defaults/main.yml`:

```yaml
---
# Packages installed on every base-managed server.
base_packages:
  - curl
  - wget
  - vim
  - htop
  - tmux
  - git
  - unzip
  - jq
  - tree
  - ncdu
  - iotop
  - net-tools
  - dnsutils
  - fail2ban
  - logrotate
  - mosh
  - fish
  - neovim
  - ripgrep

# Per-host extras (merged with base_packages).
base_packages_extra: []

# mosh-server wrapper uses this UDP port range.
base_mosh_port_range: "60842:60849"

# Timezone (timedatectl list-timezones).
base_server_timezone: "Europe/Berlin"

# Swap file size in MB (0 disables swap).
base_swap_size_mb: 2048

# Whether to dist-upgrade on every run.
base_upgrade_packages: true

# zswap — compressed swap cache in front of disk swap.
base_zswap_enabled: false
base_zswap_compressor: zstd
base_zswap_zpool: zsmalloc
base_zswap_max_pool_percent: 35
base_vm_swappiness: 60

# UFW firewall.
base_ufw_enabled: true
base_ufw_default_incoming: deny
base_ufw_default_outgoing: allow
base_ufw_rules:
  - { rule: allow, port: "{{ base_mosh_port_range }}", proto: udp, comment: "mosh" }

# Passive-update cron job (kept off by default; opt-in per host).
base_cron_passive_update: false

# server_hostname intentionally has no default — base only sets the hostname
# when host_vars/<host>.yml explicitly defines it.
```

- [ ] **Step 3: Write handlers**

Write `ansible/roles/base/handlers/main.yml`:

```yaml
---
- name: Restart SSH
  systemd:
    name: ssh
    state: restarted

- name: Restart fail2ban
  systemd:
    name: fail2ban
    state: restarted
  when: not ansible_check_mode

- name: Update GRUB
  command: update-grub
  changed_when: true
```

- [ ] **Step 4: Write cron.yml**

Write `ansible/roles/base/tasks/cron.yml`:

```yaml
---
# Optional passive-update cron job. Opt-in via base_cron_passive_update.

- name: Template passive_update.sh
  template:
    src: passive_update.j2
    dest: "~{{ username }}/passive_update.sh"
    mode: '0500'
    owner: "{{ username }}"
  become: true

- name: Set up Cronjob to passively update common Repositories
  ansible.builtin.cron:
    name: Passively update common Repositories
    minute: "0"
    user: "{{ username }}"
    job: "~/passive_update.sh"
  become: true
```

- [ ] **Step 5: Write main.yml**

Write `ansible/roles/base/tasks/main.yml`:

```yaml
---
# Server base setup. Runs as the deploy user (sudo via become) on the
# already-hardened SSH port (bootstrap moved it). Linux/Debian only.

- name: base — confirm Linux
  assert:
    that: ansible_facts['system'] == 'Linux'
    fail_msg: "base role only supports Linux servers"
  tags: [always]

# ============================================
# APT
# ============================================
- name: Update apt cache
  apt:
    update_cache: true
    cache_valid_time: 3600
  become: true
  when: ansible_facts['os_family'] == 'Debian'

- name: Dist-upgrade all packages
  apt:
    upgrade: dist
  become: true
  when:
    - ansible_facts['os_family'] == 'Debian'
    - base_upgrade_packages | bool

- name: Install base packages
  apt:
    name: "{{ base_packages + (base_packages_extra | default([])) }}"
    state: present
  become: true
  when: ansible_facts['os_family'] == 'Debian'

# ============================================
# MOSH WRAPPER
# ============================================
- name: Install mosh-server wrapper with default port range
  copy:
    dest: /usr/local/bin/mosh-server
    content: |
      #!/bin/sh
      # Managed by Ansible — base role. Injects the site UDP port range
      # ({{ base_mosh_port_range }}) so mosh clients don't need --port=.
      for arg in "$@"; do
        case "$arg" in
          -p|-p*) exec /usr/bin/mosh-server "$@" ;;
        esac
      done
      exec /usr/bin/mosh-server "$@" -p {{ base_mosh_port_range }}
    mode: '0755'
  become: true
  tags: [mosh]

# ============================================
# TIMEZONE + HOSTNAME (conditional)
# ============================================
- name: Set timezone
  command: timedatectl set-timezone {{ base_server_timezone }}
  changed_when: false
  become: true

- name: Set hostname (only when server_hostname is defined)
  hostname:
    name: "{{ server_hostname }}"
  become: true
  when: server_hostname is defined

- name: Add hostname to /etc/hosts
  lineinfile:
    path: /etc/hosts
    regexp: '^127\.0\.1\.1'
    line: "127.0.1.1 {{ server_hostname }}"
    state: present
  become: true
  when: server_hostname is defined

# ============================================
# SWAP
# ============================================
- name: Check swap file
  stat:
    path: /swapfile
  register: _swap

- name: Create and configure swap file
  when:
    - base_swap_size_mb > 0
    - not _swap.stat.exists
    - not ansible_check_mode
  become: true
  block:
    - name: Create swap file
      command: fallocate -l {{ base_swap_size_mb }}M /swapfile
      changed_when: true
    - name: Set swap file permissions
      file:
        path: /swapfile
        mode: '0600'
    - name: Format swap file
      command: mkswap /swapfile
      changed_when: true
    - name: Enable swap file
      command: swapon /swapfile
      changed_when: true
    - name: Add swap to fstab
      lineinfile:
        path: /etc/fstab
        regexp: '^/swapfile'
        line: '/swapfile none swap sw 0 0'
        state: present
  tags: [swap]

- name: Tune vm.swappiness
  ansible.posix.sysctl:
    name: vm.swappiness
    value: "{{ base_vm_swappiness }}"
    state: present
    sysctl_file: /etc/sysctl.d/90-swap-tuning.conf
    reload: true
  become: true
  tags: [swap]

# ============================================
# UFW
# ============================================
- name: Install UFW
  apt:
    name: ufw
    state: present
  become: true
  when: ansible_facts['os_family'] == 'Debian'
  tags: [firewall]

- name: Set UFW default incoming policy
  community.general.ufw:
    direction: incoming
    policy: "{{ base_ufw_default_incoming }}"
  become: true
  when: base_ufw_enabled
  tags: [firewall]

- name: Set UFW default outgoing policy
  community.general.ufw:
    direction: outgoing
    policy: "{{ base_ufw_default_outgoing }}"
  become: true
  when: base_ufw_enabled
  tags: [firewall]

- name: Configure UFW rules
  community.general.ufw:
    rule: "{{ item.rule }}"
    port: "{{ item.port }}"
    proto: "{{ item.proto }}"
    comment: "{{ item.comment | default(omit) }}"
  loop: "{{ base_ufw_rules + (ufw_rules_extra | default([])) }}"
  become: true
  when: base_ufw_enabled
  tags: [firewall]

- name: Enable UFW
  community.general.ufw:
    state: enabled
  become: true
  when: base_ufw_enabled
  tags: [firewall]

# ============================================
# FAIL2BAN
# ============================================
- name: Configure fail2ban for SSH
  copy:
    dest: /etc/fail2ban/jail.local
    content: |
      [DEFAULT]
      bantime = 86400
      findtime = 600
      maxretry = 3
      bantime.increment = true
      bantime.factor = 2
      bantime.maxtime = 604800

      [sshd]
      enabled = true
      port = {{ ansible_port | default(22) }}
      filter = sshd
      logpath = /var/log/auth.log
      maxretry = 3
      mode = aggressive
    mode: '0644'
  become: true
  notify: Restart fail2ban

- name: Enable and start fail2ban
  systemd:
    name: fail2ban
    enabled: true
    state: started
  become: true
  when: not ansible_check_mode

# ============================================
# OPTIONAL: PASSIVE UPDATE CRON
# ============================================
- include_tasks: cron.yml
  when: base_cron_passive_update | bool
  tags: [cron]
```

- [ ] **Step 6: Temp verification playbook**

Write `ansible/playbooks/_test_base.yml`:

```yaml
---
- hosts: localhost
  connection: local
  gather_facts: true
  roles:
    - base
```

- [ ] **Step 7: Syntax-check**

Run: `ansible-playbook ansible/playbooks/_test_base.yml --syntax-check`
Expected: clean.

- [ ] **Step 8: Check-mode against a registered Debian-family host (skip if none available)**

There are no currently-registered Debian hosts in `host_vars/` — caeli is macOS, jolly/tux/artus/margo/hp440g5 are NixOS. So this verification is **deferred** to whenever the first Debian server is added. Document this explicitly:

```bash
# When the first Debian host exists, run:
# ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/_test_base.yml -l <host> --check --diff
```

For now, the `assert: ansible_facts['system'] == 'Linux'` at the top of `main.yml` will fail check-mode on caeli (Darwin). Verify the assert fires correctly:

Run: `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/_test_base.yml -l caeli --check`
Expected: failure with `fail_msg: "base role only supports Linux servers"`.

- [ ] **Step 9: Delete temp playbook**

```bash
rm ansible/playbooks/_test_base.yml
```

- [ ] **Step 10: Commit**

```bash
git add ansible/roles/base/
git commit -m "ansible: add base role for Debian-family servers

Derived from ~/Coding/infrastructure/ansible/roles/base, trimmed to
the subset relevant for terminal-only VMs (no Docker group, no HTTPS
ufw rules — those belong to a future deploy role). Hostname is only
set when server_hostname is explicitly defined in host_vars, so the
ad-hoc terminal.yml playbook can run on unregistered VMs without
clobbering their hostname.

No active personal host currently uses base (NixOS handles those
concerns declaratively). Role's first real consumer will be the
first Hetzner-style VM."
```

---

### Task 10: Build `bootstrap` role

**Files:**
- Create: `ansible/roles/bootstrap/tasks/main.yml`
- Create: `ansible/roles/bootstrap/defaults/main.yml`
- Create: `ansible/roles/bootstrap/handlers/main.yml`
- Read: `~/Coding/infrastructure/ansible/roles/bootstrap/` (reference)

- [ ] **Step 1: Write defaults**

Write `ansible/roles/bootstrap/defaults/main.yml`:

```yaml
---
# Bootstrap creates this user with passwordless sudo and copies SSH keys
# from /root/.ssh/authorized_keys (the keys you used to log in as root).
bootstrap_user: pars
bootstrap_user_shell: /bin/bash
bootstrap_user_groups:
  - sudo

# SSH hardening.
bootstrap_ssh_port: 2244
bootstrap_disable_root_login: true
bootstrap_ssh_password_auth: false
bootstrap_ssh_max_auth_tries: 3
bootstrap_ssh_x11_forwarding: false
bootstrap_ssh_client_alive_interval: 300
bootstrap_ssh_client_alive_count_max: 2
```

- [ ] **Step 2: Write handlers**

Write `ansible/roles/bootstrap/handlers/main.yml`:

```yaml
---
- name: bootstrap reload systemd
  systemd:
    daemon_reload: true
  listen: bootstrap_reload_systemd

- name: bootstrap restart SSH
  systemd:
    name: ssh
    state: restarted
  listen: bootstrap_restart_ssh

- name: bootstrap restart SSH socket
  systemd:
    name: ssh.socket
    state: restarted
  register: _bootstrap_ssh_socket
  failed_when: >
    _bootstrap_ssh_socket.failed and
    'Could not find' not in (_bootstrap_ssh_socket.msg | default(''))
  listen: bootstrap_restart_ssh_socket
```

- [ ] **Step 3: Write main.yml**

Write `ansible/roles/bootstrap/tasks/main.yml`:

```yaml
---
# Runs as root@22. Creates {{ bootstrap_user }}, copies SSH keys, opens new
# SSH port in ufw, switches sshd to new port, disables root login + password
# auth. After this completes, the host is reachable ONLY as
# {{ bootstrap_user }}@{{ bootstrap_ssh_port }}.

- name: Install required packages
  apt:
    name: [sudo, ufw]
    state: present
    update_cache: true

# ============================================
# USER
# ============================================
- name: Create bootstrap user
  user:
    name: "{{ bootstrap_user }}"
    shell: "{{ bootstrap_user_shell }}"
    groups: "{{ bootstrap_user_groups }}"
    append: true
    createhome: true
    state: present

- name: Passwordless sudo for bootstrap user
  lineinfile:
    path: "/etc/sudoers.d/{{ bootstrap_user }}"
    line: "{{ bootstrap_user }} ALL=(ALL) NOPASSWD:ALL"
    create: true
    mode: '0440'
    validate: "visudo -cf %s"

- name: Create .ssh dir for bootstrap user
  file:
    path: "/home/{{ bootstrap_user }}/.ssh"
    state: directory
    owner: "{{ bootstrap_user }}"
    group: "{{ bootstrap_user }}"
    mode: '0700'

- name: Stat root authorized_keys
  stat:
    path: /root/.ssh/authorized_keys
  register: _root_keys

- name: Copy SSH authorized keys from root to bootstrap user
  copy:
    src: /root/.ssh/authorized_keys
    dest: "/home/{{ bootstrap_user }}/.ssh/authorized_keys"
    remote_src: true
    owner: "{{ bootstrap_user }}"
    group: "{{ bootstrap_user }}"
    mode: '0600'
  when: _root_keys.stat.exists

# ============================================
# FIREWALL — open new port BEFORE switching
# ============================================
- name: Allow new SSH port through UFW
  community.general.ufw:
    rule: allow
    port: "{{ bootstrap_ssh_port }}"
    proto: tcp
    comment: "SSH"

- name: Keep port 22 open during transition
  community.general.ufw:
    rule: allow
    port: "22"
    proto: tcp
    comment: "SSH (transitional)"
  when: bootstrap_ssh_port != 22

- name: Enable UFW
  community.general.ufw:
    state: enabled
    default: deny
    direction: incoming

# ============================================
# SSH HARDENING
# ============================================
- name: Configure sshd
  lineinfile:
    path: /etc/ssh/sshd_config
    regexp: "{{ item.regexp }}"
    line: "{{ item.line }}"
    state: present
    validate: 'sshd -t -f %s'
  loop:
    - { regexp: '^#?Port ',                       line: 'Port {{ bootstrap_ssh_port }}' }
    - { regexp: '^#?PermitRootLogin',             line: 'PermitRootLogin {{ "no" if bootstrap_disable_root_login else "yes" }}' }
    - { regexp: '^#?PasswordAuthentication',      line: 'PasswordAuthentication {{ "no" if not bootstrap_ssh_password_auth else "yes" }}' }
    - { regexp: '^#?PubkeyAuthentication',        line: 'PubkeyAuthentication yes' }
    - { regexp: '^#?ChallengeResponseAuthentication', line: 'ChallengeResponseAuthentication no' }
    - { regexp: '^#?UsePAM',                      line: 'UsePAM yes' }
    - { regexp: '^#?X11Forwarding',               line: 'X11Forwarding {{ "yes" if bootstrap_ssh_x11_forwarding else "no" }}' }
    - { regexp: '^#?MaxAuthTries',                line: 'MaxAuthTries {{ bootstrap_ssh_max_auth_tries }}' }
    - { regexp: '^#?ClientAliveInterval',         line: 'ClientAliveInterval {{ bootstrap_ssh_client_alive_interval }}' }
    - { regexp: '^#?ClientAliveCountMax',         line: 'ClientAliveCountMax {{ bootstrap_ssh_client_alive_count_max }}' }
  notify: bootstrap_restart_ssh

- name: Create SSH socket override directory (Ubuntu 24.04+ socket-activated sshd)
  file:
    path: /etc/systemd/system/ssh.socket.d
    state: directory
    mode: '0755'

- name: Configure SSH socket port
  copy:
    dest: /etc/systemd/system/ssh.socket.d/override.conf
    content: |
      [Socket]
      ListenStream=
      ListenStream=0.0.0.0:{{ bootstrap_ssh_port }}
      ListenStream=[::]:{{ bootstrap_ssh_port }}
    mode: '0644'
  notify:
    - bootstrap_reload_systemd
    - bootstrap_restart_ssh_socket

# Force handlers now so the next play can reconnect on the new port.
- name: Apply SSH changes immediately
  meta: flush_handlers

# ============================================
# VERIFICATION
# ============================================
- name: Test bootstrap user sudo
  command: sudo -u {{ bootstrap_user }} sudo whoami
  register: _sudo_test
  changed_when: false

- name: Verify sudo works
  assert:
    that: _sudo_test.stdout == "root"
    fail_msg: "Bootstrap user cannot sudo — SSH changes may have been applied unsafely."
    success_msg: "Bootstrap user has working sudo access."
```

- [ ] **Step 4: Syntax-check (no host run — bootstrap is destructive)**

The bootstrap role is destructive to SSH config. Don't run check-mode against a live host; just syntax-check.

Write `ansible/playbooks/_test_bootstrap.yml`:

```yaml
---
- hosts: localhost
  connection: local
  gather_facts: true
  roles:
    - bootstrap
```

Run: `ansible-playbook ansible/playbooks/_test_bootstrap.yml --syntax-check`
Expected: clean.

```bash
rm ansible/playbooks/_test_bootstrap.yml
```

- [ ] **Step 5: Commit**

```bash
git add ansible/roles/bootstrap/
git commit -m "ansible: add bootstrap role for fresh-server hardening

Derived from ~/Coding/infrastructure/ansible/roles/bootstrap. Default
user renamed to 'pars'. Runs as root@22, creates the user with
passwordless sudo, copies SSH keys from /root, moves sshd to a new
port, disables root + password auth. Cannot continue in the same
play afterward — the connection params have changed.

No check-mode verification possible against a live host (the play is
destructive); syntax-check only at this stage. First real run will
be against a fresh Hetzner VM."
```

---

### Task 11: Write site.yml and entry playbooks

**Files:**
- Modify: `ansible/site.yml` (replace placeholder)
- Create: `ansible/playbooks/bootstrap.yml`
- Create: `ansible/playbooks/terminal.yml`

- [ ] **Step 1: Replace placeholder site.yml**

Write `ansible/site.yml`:

```yaml
---
# Main playbook. Loops over each host's host_roles list with include_role,
# applying the role name as a tag for filtering.
#
# Invocation:
#   # push from workstation
#   ansible-playbook ansible/site.yml -l caeli
#
#   # pull on host (resolves host_vars via -e host_id=<name> because
#   # inventory_hostname is always 'localhost' under ansible-pull)
#   ansible-pull -U <repo-url> ansible/site.yml -e host_id=$(hostname)

- hosts: all
  gather_facts: true

  pre_tasks:
    - name: Resolve host_id (defaults to inventory_hostname)
      set_fact:
        resolved_host_id: "{{ host_id | default(inventory_hostname) }}"
      tags: [always]

    - name: Load host_vars for resolved host_id
      include_vars:
        file: "host_vars/{{ resolved_host_id }}.yml"
      when: host_id is defined and host_id != inventory_hostname
      tags: [always]

    - name: Assert host_roles is set
      assert:
        that:
          - host_roles is defined
          - host_roles | length > 0
        fail_msg: "Host '{{ resolved_host_id }}' has no host_roles list. Add ansible/host_vars/{{ resolved_host_id }}.yml or pass -e host_id=<registered_host>."
      tags: [always]

  tasks:
    - name: Apply role {{ item }}
      include_role:
        name: "{{ item }}"
        apply:
          tags: ["{{ item }}"]
      loop: "{{ host_roles }}"
      tags: [always]
```

The `include_vars` under `host_id != inventory_hostname` handles the `ansible-pull` case where `inventory_hostname` is `localhost` but the operator passed `-e host_id=jolly`. In normal push mode (`-l caeli`), `inventory_hostname` is already `caeli` and host_vars is auto-loaded by ansible's standard host_vars discovery.

- [ ] **Step 2: Write bootstrap entry playbook**

Write `ansible/playbooks/bootstrap.yml`:

```yaml
---
# First-boot playbook. Runs ONLY the bootstrap role.
# Connection identity passed at the command line:
#   ansible-playbook ansible/playbooks/bootstrap.yml -l <host> \
#     -e ansible_user=root -e ansible_port=22 -e bootstrap_user=pars
#
# After this completes, the host is reachable only as
# <bootstrap_user>@<bootstrap_ssh_port>. Add ansible/host_vars/<host>.yml
# and run ansible/site.yml next.

- hosts: all
  become: true
  gather_facts: true

  vars_prompt:
    - name: confirm_bootstrap
      prompt: |

        ⚠️  BOOTSTRAP MODE — will:
          • Create user '{{ bootstrap_user | default("pars") }}'
          • Copy /root SSH keys to the new user
          • Move sshd to port {{ bootstrap_ssh_port | default(2244) }}
          • Disable root SSH login and password auth

        Continue? (yes/no)
      private: false
      default: "no"

  pre_tasks:
    - name: Abort if not confirmed
      fail:
        msg: "Bootstrap cancelled."
      when: confirm_bootstrap != "yes"

    - name: Display target info
      debug:
        msg: |
          ================================================
          BOOTSTRAPPING: {{ inventory_hostname }}
          OS:   {{ ansible_distribution }} {{ ansible_distribution_version }}
          IP:   {{ ansible_default_ipv4.address | default('N/A') }}
          User: {{ ansible_user_id }}
          New SSH port: {{ bootstrap_ssh_port | default(2244) }}
          ================================================

  roles:
    - bootstrap

  post_tasks:
    - debug:
        msg: |
          ================================================
          ✅ BOOTSTRAP COMPLETE
          ================================================
          NEXT STEPS:
          1. Update ~/.ssh/config on your workstation:
             Host {{ inventory_hostname }}
                 Hostname {{ ansible_host | default(inventory_hostname) }}
                 User {{ bootstrap_user | default('pars') }}
                 Port {{ bootstrap_ssh_port | default(2244) }}
          2. Create ansible/host_vars/{{ inventory_hostname }}.yml
          3. Run: ansible-playbook ansible/site.yml -l {{ inventory_hostname }}
          ================================================
```

- [ ] **Step 3: Write ad-hoc terminal entry playbook**

Write `ansible/playbooks/terminal.yml`:

```yaml
---
# Ad-hoc playbook for unregistered hosts. Applies base + terminal_dotfiles
# with sensible defaults and does NOT set the hostname.
#
# Invocation (push, after bootstrap):
#   ansible-playbook ansible/playbooks/terminal.yml -l <host>
#
# Invocation (pull, from on the host):
#   ansible-pull -U <repo-url> ansible/playbooks/terminal.yml

- hosts: all
  gather_facts: true

  vars:
    # Force these off for ad-hoc invocation — only registered hosts opt in.
    confirm_overwrite: false

  roles:
    - { role: base, when: ansible_facts['os_family'] == 'Debian' }
    - terminal_dotfiles
```

- [ ] **Step 4: Syntax-check all entry playbooks**

```bash
ansible-playbook ansible/site.yml --syntax-check
ansible-playbook ansible/playbooks/bootstrap.yml --syntax-check
ansible-playbook ansible/playbooks/terminal.yml --syntax-check
```

Expected: all three report `playbook: <path>` with no errors.

- [ ] **Step 5: Commit**

```bash
git add ansible/site.yml ansible/playbooks/
git commit -m "ansible: wire orchestration (site.yml + bootstrap/terminal playbooks)

site.yml resolves host_vars via host_id|default(inventory_hostname) and
loops over the host's host_roles list with include_role, applying the
role name as a tag.

playbooks/bootstrap.yml runs only the bootstrap role with a
vars_prompt confirmation gate.

playbooks/terminal.yml is ad-hoc: base (Debian only) + terminal_dotfiles
with confirm_overwrite forced off. Suitable for ansible-pull on
unregistered hosts."
```

---

### Task 12: End-to-end check-mode verification per registered host

**Files:** none modified — verification only.

- [ ] **Step 1: Run --check --diff against caeli (macOS)**

```bash
ansible-playbook ansible/site.yml -l caeli --check --diff > /tmp/check-caeli-new.log 2>&1
ansible-pull -U "$(pwd)" general.yml -e client_role=caeli --check --diff -d /tmp/old-pull --accept-host-key 2>&1 > /tmp/check-caeli-old.log || true
```

(The second command is best-effort — `ansible-pull -d` clones into a temp dir; if it fails for env reasons, that's fine. The new run is the authoritative one.)

Inspect `/tmp/check-caeli-new.log` — verify:
- All four roles in caeli's host_roles list run (terminal_dotfiles, os_macos, graphical_dotfiles, coding_agents)
- No fatal errors
- Total `changed=` count is small (mostly idempotent — symlinks and brew already in place)
- If any task is `changed`, justify it: it must be a real divergence from old behavior or a known-acceptable improvement.

- [ ] **Step 2: Run --check --diff against each other registered host**

For each of jolly, tux, artus, margo, hp440g5 (all NixOS):

```bash
ansible-playbook ansible/site.yml -l jolly --check --diff > /tmp/check-jolly.log 2>&1
ansible-playbook ansible/site.yml -l tux   --check --diff > /tmp/check-tux.log 2>&1
# etc.
```

For each, verify the host_roles list is applied cleanly. NixOS hosts don't have `base` in their list, so apt-related tasks are not exercised.

Inspect each log for failures. Investigate any unexpected `changed` results.

- [ ] **Step 3: If any failures, fix in a follow-up step and re-run**

If a role file needs adjustment to match observed behavior on a specific host:
1. Edit the role file.
2. Re-run the failing host's `--check --diff`.
3. Repeat until clean.
4. Commit the fix with a message like `ansible: fix <issue> in <role> revealed by --check on <host>`.

If no failures: nothing to commit. Proceed to Task 13.

---

### Task 13: Write bootstrap.sh

**Files:**
- Create: `bootstrap.sh`

- [ ] **Step 1: Write bootstrap.sh**

Write `bootstrap.sh`:

```bash
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x bootstrap.sh
```

- [ ] **Step 3: Lint shell script**

Run: `shellcheck bootstrap.sh` (if shellcheck installed locally)
Expected: no warnings, or only `SC1091` (sourced file not followed) which is suppressed.

If shellcheck isn't available, skip — `sh -n bootstrap.sh` catches syntax errors.

Run: `sh -n bootstrap.sh`
Expected: no output (clean parse).

- [ ] **Step 4: Commit**

```bash
git add bootstrap.sh
git commit -m "ansible: add bootstrap.sh green-field entrypoint

POSIX-compliant; detects distro (debian/ubuntu/fedora/arch/macos),
installs ansible if missing, runs ansible-pull against either
ansible/playbooks/terminal.yml (default) or ansible/site.yml when
BOOTSTRAP_HOST_ID is set."
```

---

### Task 14: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace usage section**

Replace lines 36–60 of `README.md` (the "Usage" and "Overwriting Existing Config Directories" sections) with the new commands. Read the file first to confirm line numbers, then edit.

The new content for the section starting at `### Usage`:

```markdown
### Usage

**Fresh server, single-paste pull-mode** (installs ansible if missing, runs base + terminal_dotfiles):

```
curl -fsSL https://raw.githubusercontent.com/fkarg/configs/master/bootstrap.sh | sh
```

For a registered host, set `BOOTSTRAP_HOST_ID` so site.yml runs instead:

```
BOOTSTRAP_HOST_ID=jolly curl -fsSL https://raw.githubusercontent.com/fkarg/configs/master/bootstrap.sh | sh
```

**Registered host, ongoing config (push from workstation):**

```
ansible-playbook ansible/site.yml -l caeli
ansible-playbook ansible/site.yml -l caeli --check --diff   # dry-run
ansible-playbook ansible/site.yml -l caeli --tags fish      # just fish
ansible-playbook ansible/site.yml -l caeli --tags coding_agents
```

**Registered host, on-host pull:**

```
ansible-pull -U git@github.com:fkarg/configs.git ansible/site.yml -e host_id=$(hostname)
```

**First-boot SSH hardening of a fresh Debian/Ubuntu server (run from your workstation as root@22):**

```
ansible-playbook ansible/playbooks/bootstrap.yml -l new-host \
  -e ansible_user=root -e ansible_port=22 -e bootstrap_user=pars
```

After this completes, the host is reachable as `pars@<bootstrap_ssh_port>` (default 2244). Update `~/.ssh/config`, add `ansible/host_vars/new-host.yml`, then run `site.yml`.

### Overwriting Existing Config Directories

Some applications (fish, kitty, nvim, broot) create their own config directories on first launch. If these exist as real directories (not symlinks), the playbook skips the symlink by default to avoid data loss. To force the symlink (deleting the existing directory first):

```
ansible-playbook ansible/site.yml -l caeli -e confirm_overwrite=true
```

This flag is ignored under `--check` mode for safety.
```

- [ ] **Step 2: Read README and apply edit**

```bash
# Confirm current README structure first:
sed -n '36,60p' README.md
```

Edit using the Edit tool with the old block (current lines 36–60) replaced by the new block above.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: update README for new ansible commands

Replaces old client_role-based invocation with the new role-based
layout: bootstrap.sh for green-field, ansible-playbook for registered
hosts, ansible-pull on-host with host_id."
```

---

### Task 15: Delete legacy files

**Files:**
- Delete: `general.yml`
- Delete: entire `tasks/` directory
- Delete: entire `vars/` directory
- Delete: entire `handlers/` directory
- Delete: entire `defaults/` directory
- Delete: entire `templates/` directory

- [ ] **Step 1: Confirm new playbook still works end-to-end before deletion**

```bash
ansible-playbook ansible/site.yml -l caeli --check --diff > /tmp/final-check.log 2>&1
echo "exit: $?"
tail -20 /tmp/final-check.log
```

Expected: exit 0, last line includes `failed=0`.

- [ ] **Step 2: Delete legacy directories and general.yml**

```bash
git rm general.yml
git rm -r tasks/ vars/ handlers/ defaults/ templates/
```

- [ ] **Step 3: Verify nothing else in the repo references the deleted paths**

```bash
grep -rn -E '(^|/)(tasks|vars|handlers|defaults|templates)/' \
  --include='*.yml' --include='*.yaml' --include='*.sh' --include='*.md' \
  --exclude-dir=.git --exclude-dir=ansible --exclude-dir=docs . || echo "no stale refs"
```

Expected: `no stale refs` (or only legitimate ansible/ references).

Also check that `general.yml` isn't referenced anywhere:

```bash
grep -rn 'general\.yml' --exclude-dir=.git . || echo "no refs to general.yml"
```

Expected: `no refs to general.yml`.

- [ ] **Step 4: Final syntax check**

```bash
ansible-playbook ansible/site.yml --syntax-check
ansible-playbook ansible/playbooks/bootstrap.yml --syntax-check
ansible-playbook ansible/playbooks/terminal.yml --syntax-check
```

Expected: all three clean.

- [ ] **Step 5: Commit**

```bash
git commit -m "ansible: delete legacy playbook + tasks/vars/handlers/defaults/templates

Final step of the ansible restructure. The repo now has:
- ansible.cfg at root
- bootstrap.sh at root
- ansible/ containing all role/playbook/inventory content
- old general.yml + flat tasks/ + vars/ + handlers/ + defaults/ +
  templates/ removed

See docs/superpowers/specs/2026-05-19-ansible-restructure-design.md
for the design rationale and docs/superpowers/plans/
2026-05-19-ansible-restructure.md for the task-by-task sequence."
```

---

## Self-review notes

After writing all tasks I checked:

- **Spec coverage:** all 6 roles, the link_dotdir helper, both invocation modes, the bootstrap.sh script, README update, and the legacy deletion are each covered by at least one task. The `nixos_link` role is out of scope (per spec) and absent from the plan, as intended.
- **Variable consistency:** the plan uses `host_roles` (not `roles`) throughout, `bootstrap_user` (not `deploy_user`) consistently in bootstrap role, `server_hostname` only in base (not bootstrap), `confirm_overwrite` defaulted to `false` in `terminal_dotfiles/defaults/main.yml` and forced `false` in `playbooks/terminal.yml`. `enable_broot` defaults to `false` in `terminal_dotfiles/defaults`; broot tasks live in `graphical_dotfiles`, gated by the same var.
- **Path resolution:** `repo_root` is defined in `group_vars/all.yml` so roles can reference files outside `ansible/` (like `coding-agents/build.py`) regardless of which entry playbook is used. The regex handles both `<repo>/ansible` and `<repo>/ansible/playbooks` for `playbook_dir`.
- **Verification gaps:** `base` role has no live-host check verification because none of the active personal hosts are Debian. This is explicitly documented in Task 9 Step 8. `bootstrap` role has no check-mode run because the role is destructive; documented in Task 10 Step 4.
- **Cross-task references:** Task 6 (`terminal_dotfiles`) creates `link_dotdir.yml`; Task 7 (`graphical_dotfiles`) consumes it via `include_role: tasks_from: link_dotdir`. Task 7 depends on Task 6 having completed.
