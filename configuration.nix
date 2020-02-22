{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./programs.nix
      ./machines/default.nix
      # ./machines/(tux|home).nix
      ./pars.nix
    ];

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  system.stateVersion = "19.09";
  system.autoUpgrade.enable = true;
  system.dates = "12:00"
}

# open questions:
# - what does 'rec' do?
# - what does 'callPackage' do?
# - what does 'inherit' do exactly?
# - how does 'with' work, in detail?
