# # put here:
# modify config for i3status-rs (battery, network)
# adapt fish/config (greet on tux)
# add /datadisk to fstab
#
# modify startup script:
# - setting background
{ config, pkgs, ... }: with pkgs; rec

{
  boot.loader.grub.device = "/dev/sda";
  boot.kernelParams = [ "mitigations=off" "splash"];

  networking.hostName = "tux";

  fileSystems."/datadisk" =
    { device = "/dev/disk/by-uuid/c8425c4c-ec6b-4edd-ba68-2fbbb71ab78b";
      fsType = "ext4";
    };

  networking.interfaces.enp3s0f1.useDHCP = true;
  networking.interfaces.wlp2s0.useDHCP = true;

  environment.systemPackages = [
    # xbacklight:
    acpilight
    lxd
    docker
  ];
  virtualisation.lxd.enable = true;
  virtualisation.docker.enable = true;

  # enable touchpad support
  services.xserver.libinput = {
    enable = true;
    touchpad.disableWhileTyping = true;
  };

  # bluetooth
  # $ bluetoothctl
  # [bluetooth] # power on
  # [bluetooth] # agent on
  # [bluetooth] # default-agent
  # [bluetooth] # scan on
  # ...put device in pairing mode and wait [hex-address] to appear here...
  # [bluetooth] # pair [hex-address]
  # [bluetooth] # connect [hex-address]
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  hardware.acpilight.enable = true;
  hardware.pulseaudio.extraConfig = "load-module module-udev-detect use_ucm=0 tsched=0\nload-module module-echo-cancel source_name=noechosource sink_name=noechosink\nset-default-source noechosource\nset-default-sink noechosink";
  hardware.pulseaudio.daemon.config = {
    # flat-volumes=no
    resample-method="speex-float-5";
    default-sample-rate = 48000;
    # resample-method = "src-sinc-best-quality";
    default-sample-format = "s16le";
  };

  imports =
    [
      /home/pars/vpn/vpn_config.nix
    ];
}
