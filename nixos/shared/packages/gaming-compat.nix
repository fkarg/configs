{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Steam and Proton compatibility tools
    steam-run
    protonup-qt
    mangohud
    goverlay
  ];
}