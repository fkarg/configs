# # put here:
# modify config for i3status-rs (battery, network)
# adapt fish/config (greet on tux)
# add /datadisk to fstab
#
# modify startup script:
# - setting background
{ config, pkgs, ... }: with pkgs; rec

{
  boot.loader.grub.device = "/dev/sdb";

  networking.hostName = "tux";

  networking.interfaces.enp3s0f1.useDHCP = true;
  networking.interfaces.wlp2s0.useDHCP = true;

  # enable touchpad support
  services.xserver.libinput.enable = true;

  environment.systemPackages = [
    # xbacklight:
    acpilight
  ];

  hardware.brightnessctl.enable = true; # for xbacklight
}

