{ config, pkgs, ... }:

{
  # Reference/example entrypoint only.
  #
  # This repository is shared across multiple machines and platforms. The real
  # host configuration for an active machine may import these modules from a
  # different top-level path, and machine-local generated hardware state may
  # intentionally remain outside the public repo.
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # does this really import them the way I think? import the higher ones
      # 'first', and override sub-parts based on the lower ones?
      ./nixos/programs.nix
      ./nixos/machines/default.nix
      # machine-specific config (change to match current host):
      ./nixos/machines/jolly.nix
      ./nixos/pars.nix
    ];

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  system.stateVersion = "25.11";
  system.autoUpgrade.enable = true;
}

# open questions:
# - what does 'rec' do?
# - what does 'callPackage' do?
# - what does 'inherit' do exactly?
# - how does 'with' work, in detail?
