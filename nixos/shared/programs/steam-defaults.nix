{ pkgs, ... }:

{
  # Modern Steam defaults based on the current NixOS Steam module.
  # Prefer supported module options over per-machine steam.override hacks.
  programs.steam = {
    enable = true;
    protontricks.enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
    extraPackages = with pkgs; [
      gamescope
      mangohud
    ];
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };

  hardware.steam-hardware.enable = true;
}