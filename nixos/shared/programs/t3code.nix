{ pkgs, ... }:

# T3 Code's release package is evaluated from upstream's latest stable Linux
# release manifest in ../../pkgs/t3code.
{
  environment.systemPackages = [
    (pkgs.callPackage ../../pkgs/t3code/package.nix { })
  ];
}
