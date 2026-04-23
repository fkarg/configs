{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # desktop helpers
    redshift
    feh
    screen-message
    baobab
    scrot
    shutter
    file-roller
    pavucontrol

    # desktop integration and hardware helpers
    networkmanagerapplet
    intel-gpu-tools
    libva-utils
  ];
}