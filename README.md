# configs

This is a collection of configuration files and related automation parts.

Especially of interest could be the nix-configuration files (mainly in the `nixos` folder), and the ansible setup of local files.

### Client\_Roles
Currently available `client_role`s are:
- tux
- hp440g5
- desktop
- terminal
- caeli (macOS)

each has it's own little modifications.

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
