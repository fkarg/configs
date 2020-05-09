# configs

This is a collection of configuration files and related automation parts.

Especially of interest could be the nix-configuration files (mainly in the `nixos` folder), and the ansible setup of local files.

### Usage:
`ansible-pull --clean -U git@github.com:fkarg/configs.git general.yml -e client_role=<client>`

Make sure you have an ssh key which is registered on your github account for this computer already.
