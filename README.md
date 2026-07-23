# configs

This is a collection of configuration files and related automation parts.

Especially of interest could be the nix-configuration files (mainly in the `nixos` folder), and the ansible setup of local files.

## Migration Notes

Top-level `configuration.nix` note:

- `configuration.nix` in this repo is a reference/example entrypoint, not the authoritative live entrypoint for every machine.
- The repo is shared across multiple machines, including non-NixOS hosts.
- Machine-local generated hardware details may intentionally stay in `/etc/nixos/hardware-configuration.nix` on the target host.

NixOS notes:

- The active NixOS entrypoint on a host can be `/etc/nixos/configuration.nix`, which may import this repo through `/etc/nixos/configs`.
- Host-specific NixOS behavior belongs in the matching machine module under `nixos/machines/`.
- Shared desktop plumbing for Hyprland, PipeWire, and app defaults lives under `nixos/shared/`.
- For `jolly`, the important recovery rule is to prepare upgrades for the next boot instead of live-switching the graphical stack.

## Client Roles

Currently available `client_role`s are:

- tux (Tuxedo laptop, defunct)
- hp440g5 (previous work laptop, defunct)
- desktop (old tower, defunct)
- terminal (generic server config, active)
- artus/margo (NixOS on Framework)
- caeli (macOS)
- jolly (NixOS on tower PC)

each has it's own modifications.

### Usage

**Fresh server, single-paste pull-mode** (installs ansible if missing, runs base + terminal_dotfiles):

```sh
curl -fsSL https://raw.githubusercontent.com/fkarg/configs/master/bootstrap.sh | sh
```

For a registered host, set `BOOTSTRAP_HOST_ID` so site.yml runs instead:

```sh
BOOTSTRAP_HOST_ID=jolly curl -fsSL https://raw.githubusercontent.com/fkarg/configs/master/bootstrap.sh | sh
```

For a **generic terminal/VM** (no per-host file, just `base + terminal_dotfiles` via the normal site.yml flow — no firewall changes, no personal git identity, no private repos), use the shared `terminal` profile:

```
BOOTSTRAP_HOST_ID=terminal curl -fsSL https://raw.githubusercontent.com/fkarg/configs/master/bootstrap.sh | sh
```

Or, when the repo is already checked out and you just want to (re)apply the profile locally (`terminal` is a local alias in `hosts.yml`):

```
ansible-playbook ansible/site.yml -l terminal
```

See `ansible/inventory/host_vars/terminal.yml` for the knobs it exposes.

#### Role layers

| Role | Scope | Used by |
|---|---|---|
| `bootstrap` | Initial SSH/user hardening on a fresh Debian/Ubuntu box (runs as root@22, switches sshd port, creates the deploy user). | Run once via `playbooks/bootstrap.yml`. |
| `base` | Universally safe Linux baseline: apt updates, common shell/editor/network packages, mosh-server wrapper, timezone, `vm.swappiness`. No firewall, no fail2ban, no swap file, no hostname rewrite. | Every Linux host. |
| `server_hardening` | Opt-in server lockdown: UFW (deny incoming), fail2ban, swap file, hostname-set (when `server_hostname` is defined). | Production-facing servers only. Add to `host_roles` and set `ufw_rules_extra` with your sshd port. |
| `terminal_dotfiles` | Generic dotfiles: configs repo clone, `.gitconfig` template (identity comes from `group_vars/all.yml`), fish/nvim/vim symlinks, templated fish config. | Every host that wants the shell setup, including the generic `terminal` profile. |
| `personal` | Private repos (`text_zeug`, `gtd`, `finances`) and the optional passive-update cron that pulls/pushes them. | Personal machines only. |
| `graphical_dotfiles` | i3/Hyprland/X resources, GUI dotfiles. | Workstations with a display. |
| `os_macos` | Homebrew package + cask management, macOS defaults. | macOS hosts. |
| `coding_agents` | Symlinks for global config of various coding-agent CLIs (claude, etc.). | Hosts that run those agents. |

**Registered host, ongoing config (push from workstation):**

```sh
ansible-playbook ansible/site.yml -l caeli
ansible-playbook ansible/site.yml -l caeli --check --diff   # dry-run
ansible-playbook ansible/site.yml -l caeli --tags fish      # just fish
ansible-playbook ansible/site.yml -l caeli --tags coding_agents
```

**Registered host, on-host pull:**

```sh
ansible-pull -U git@github.com:fkarg/configs.git ansible/site.yml -e host_id=$(hostname)
```

**First-boot SSH hardening of a fresh Debian/Ubuntu server (run from your workstation as root@22):**

```sh
ansible-playbook ansible/playbooks/bootstrap.yml -l new-host \
  -e ansible_user=root -e ansible_port=22 -e bootstrap_user=pars
```

After this completes, the host is reachable as `pars@<bootstrap_ssh_port>` (default 2244). Update `~/.ssh/config`, add `ansible/inventory/host_vars/new-host.yml`, then run `site.yml`.

### Overwriting Existing Config Directories

Some applications (fish, kitty, nvim, broot, lf) create their own config directories on first launch. If these exist as real directories (not symlinks), the playbook skips the symlink by default to avoid data loss. To force the symlink (deleting the existing directory first):

```sh
ansible-playbook ansible/site.yml -l caeli -e confirm_overwrite=true
```

This flag is ignored under `--check` mode for safety.

Make sure you have an ssh key which is registered on your github account for this computer already.

## Related configs & further resources

Actively-maintained repos that occupy the same "Ansible-as-provisioner + Nix-for-Nix-hosts + raw dotfiles" niche. Useful both as prior art and as concrete migration targets for the TODOs below.

- **[valiantlynx/dotfiles](https://github.com/valiantlynx/dotfiles)** — the closest architectural twin. `curl` bootstrap → OS-detect → install Ansible → `main.yml` with `pre_tasks/`+`group_vars/`+`roles/`, one role per tool, and NixOS kept as its own sub-tree (Ubuntu/Arch/NixOS/macOS/Windows). Same push model and role-per-tool layering as here. Read it to sanity-check our Ansible layering against a parallel-evolved twin; nothing to import directly.
- **[szaffarano/nix-dotfiles](https://github.com/szaffarano/nix-dotfiles)** — same "keep Ansible *and* Nix" philosophy, but the mature Nix end-state we haven't reached: flake with `home-manager`, `nixos-hardware`, `sops-nix`, and `renovate`. The best single reference for the `flakes?` / `nixos-hardware` TODOs below.
- **[alyraffauf/infra](https://github.com/alyraffauf/infra)** — broader scope (adds K8s + Terraform) but the same flake + Ansible + sops + renovate spine. Useful if this repo ever grows a real server fleet.
- **[eoli3n/dotfiles](https://github.com/eoli3n/dotfiles)** — pure-Ansible (no Nix), but *the* reference for Ansible-driven dotfiles with `host_vars`/`group_vars` and **Docker-based role testing** in CI. Directly relevant to our "no tests/lint" gap.

Tradeoffs worth a deliberate decision rather than drift:

- **home-manager vs. raw-dotfiles-via-Ansible.** They manage user dotfiles *as Nix* on Nix hosts (rollback, atomicity); we symlink raw dotfiles via `terminal_dotfiles`/`graphical_dotfiles` (editable-in-place, portable to non-Nix hosts — a real advantage for the `terminal` profile). Not a clear win either way.
- **sops-nix / sops for secrets.** Since this repo is public and deliberately tracks no secrets, sops would let secrets live encrypted *in-repo* instead of being kept out entirely — only worth it if that constraint ever chafes.

What's genuinely unique here (no dedup opportunity found): the `coding-agents/` generator that fans one source file out to four CLIs with per-tool permission translation. No comparable repo surfaced.

## TODO

flakes? — see `szaffarano/nix-dotfiles` above for the flake + `nixos-hardware` end-state
fetchgit nixos-hardware ?? common-modules davon
- fish plugin to show command history
