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

After this completes, the host is reachable as `pars@<bootstrap_ssh_port>` (default 2244). Update `~/.ssh/config`, add `ansible/inventory/host_vars/new-host.yml`, then run `site.yml`.

### Overwriting Existing Config Directories

Some applications (fish, kitty, nvim, broot) create their own config directories on first launch. If these exist as real directories (not symlinks), the playbook skips the symlink by default to avoid data loss. To force the symlink (deleting the existing directory first):

```
ansible-playbook ansible/site.yml -l caeli -e confirm_overwrite=true
```

This flag is ignored under `--check` mode for safety.

Make sure you have an ssh key which is registered on your github account for this computer already.


## TODO

flakes?
fetchgit nixos-hardware ?? common-modules davon
