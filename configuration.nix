{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      # does this really import them the way I think? import the higher ones
      # 'first', and override sub-parts based on the lower ones?
      ./nixos/programs.nix
      ./nixos/machines/default.nix
      # ./machines/(tux|home).nix
      ./nixos/pars.nix
    ];

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  system.stateVersion = "22.11";
  system.autoUpgrade.enable = true;
}

# open questions:
# - what does 'rec' do?
# - what does 'callPackage' do?
# - what does 'inherit' do exactly?
# - how does 'with' work, in detail?
