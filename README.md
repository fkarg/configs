# configs

This is a collection of configuration files and related automation parts.

Especially of interest could be the nix-configuration files (mainly in the `nixos` folder), and the ansible setup of local files.

### Client\_Roles
Currently available `client_role`s are:
- tux
- hp440g5
- desktop
- terminal

each has it's own little modifications.

### Usage:
`ansible-pull --clean -U git@github.com:fkarg/configs.git general.yml -e client_role=<client>`

if you would like to see what would change first:

`ansible-pull --check --diff --clean -U git@github.com:fkarg/configs.git general.yml -e client_role=<client>`

or, if you prefer colorful output:

`env ANSIBLE_FORCE_COLOR=true ansible-pull --clean -U git@github.com:fkarg/configs.git general.yml -e client_role=<client>`

Make sure you have an ssh key which is registered on your github account for this computer already.
