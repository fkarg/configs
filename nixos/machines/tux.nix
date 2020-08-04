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
  boot.kernelParams = [ "mitigations=off" ];

  networking.hostName = "tux";

  networking.interfaces.enp3s0f1.useDHCP = true;
  networking.interfaces.wlp2s0.useDHCP = true;

  environment.systemPackages = [
    # xbacklight:
    acpilight
    lxd
  ];
  virtualisation.lxd.enable = true;

  # enable touchpad support
  services.xserver.libinput = {
    enable = true;
    disableWhileTyping = true;
  };

  hardware.acpilight.enable = true;
}

