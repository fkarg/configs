{ pkgs, ... }:

# Stably Orca — an Electron IDE for orchestrating coding agents in parallel git
# worktrees. Not in nixpkgs, so it is packaged from upstream's .deb in
# ../../pkgs/stably-orca.
#
# There is nothing to update: the package resolves the current release from
# upstream's manifest during evaluation, so `nixos-rebuild boot` stages whatever
# is current at that moment. Each generation still holds the concrete version it
# was built with, so booting an older generation gets that older Orca back, for
# as long as nix.gc keeps it.
{
  environment.systemPackages = [
    (pkgs.callPackage ../../pkgs/stably-orca/package.nix { })
  ];
}
