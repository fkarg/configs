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

- tux
- hp440g5
- desktop
- terminal
- artus/margo (NixOS on Framework)
- caeli (macOS)
- jolly (NixOS on tower PC)

each has it's own modifications.

### Usage

`ansible-pull --diff --clean -U git@github.com:fkarg/configs.git general.yml -e client_role=<client>`

if you would like to see what would change first:

`ansible-pull --check --diff --clean -U git@github.com:fkarg/configs.git general.yml -e client_role=<client>`

or, if you prefer colorful output:

`env ANSIBLE_FORCE_COLOR=true ansible-pull --diff --clean -U git@github.com:fkarg/configs.git general.yml -e client_role=<client>`

### Overwriting Existing Config Directories

Some applications (fish, kitty, nvim, broot) create their own config directories on first launch. If these exist as real directories (not symlinks), the playbook will fail by default to avoid data loss.

To allow overwriting existing config directories with symlinks, pass `confirm_overwrite=true`:

`ansible-pull --diff --clean -U git@github.com:fkarg/configs.git general.yml -e client_role=<client> -e confirm_overwrite=true`

This flag is ignored in check mode (`--check`), so you can safely preview changes without risk.

Make sure you have an ssh key which is registered on your github account for this computer already.
