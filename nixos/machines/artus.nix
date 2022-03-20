# # put here:
# modify config for i3status-rs (battery, network)
# adapt fish/config (greet on tux)
# add /datadisk to fstab
#
# modify startup script:
# - setting background
{ config, pkgs, ... }: with pkgs; rec

{



  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # networking
  networking.hostName = "artus";
  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.wlp170s0.useDHCP = true;
  # networking.networkmanager.enable = true;

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

  # enable fingerprent sensor
  services.fprintd.enable = true;

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
  # hardware.pulseaudio.extraConfig = "load-module module-udev-detect use_ucm=0 tsched=0\nload-module module-echo-cancel source_name=noechosource sink_name=noechosink\nset-default-source noechosource\nset-default-sink noechosink";
  # hardware.pulseaudio.daemon.config = {
  #   # flat-volumes=no
  #   resample-method="speex-float-5";
  #   default-sample-rate = 48000;
  #   # resample-method = "src-sinc-best-quality";
  #   default-sample-format = "s16le";
  # };

  # imports =
  #   [
  #     /home/pars/vpn/vpn_config.nix
  #   ];
}
