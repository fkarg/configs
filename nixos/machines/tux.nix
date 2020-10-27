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

  fileSystems."/datadisk/" =
    { device = "/dev/disk/by-uuid/c8425c4c-ec6b-4edd-ba68-2fbbb71ab78b";
      fsType = "ext4";
    };

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

