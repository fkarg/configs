{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nixos/programs.nix
      ./nixos/machines/default.nix
      # ./machines/(tux|home).nix
      ./nixos/machines/tux.nix
      ./nixos/pars.nix
    ];

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  system.stateVersion = "19.09";
  system.autoUpgrade.enable = true;
}

# open questions:
# - what does 'rec' do?
# - what does 'callPackage' do?
# - what does 'inherit' do exactly?
# - how does 'with' work, in detail?
