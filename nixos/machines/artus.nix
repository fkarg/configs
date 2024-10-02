# # put here:
# modify config for i3status-rs (battery, network)
# adapt fish/config (greet on tux)
# add /datadisk to fstab
#
# modify startup script:
# - setting background
{ config, pkgs, ... }: with pkgs; rec

{

  # `i915.enable_psr=1`:  force-enable psr (should be enabled default in >=5.14) to reach deeper suspend states on idle
  # `mem_sleep_default=deep`: 'shutdown' system and go to deep suspension instead of `s2idle`. This trades reduced energy consumption for increased resume time delay.
  # boot.kernelParams = [ "mem_sleep_default=deep" "nvme.noacpi=1" "mitigations=off" "fsck.mode=force" "fsck.repair=yes" "i915.enable_psr=1"];
  boot.kernelParams = [ "mem_sleep_default=deep" "nvme.noacpi=1" "fsck.mode=force" "fsck.repair=yes"];
  # boot.kernelParams = [ "mem_sleep_default=deep" ];
  # run `sudo powertop --auto-tune` on startup. Reduces power consumption on idle
  powerManagement.powertop.enable = true;

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/c9776b0b-dd89-4489-8c8c-10d0d3ca5f02";
      fsType = "ext4";
    };

  boot.initrd.luks.devices."enc".device = "/dev/disk/by-uuid/471f76bc-106b-4ceb-b071-5498308a0fe9";

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/9535-F294";
      fsType = "vfat";
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/214069b2-e87d-482f-940a-b235e42afcd5";
      fsType = "ext4";
    };

  fileSystems."/var/lib/docker" =
    { device = "/dev/disk/by-uuid/bd670182-4860-43b1-a74a-b94ab669a23d";
      fsType = "ext4";
    };


  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # networking
  networking.hostName = "artus";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  # networking.useDHCP = false; # already set globally in default
  networking.interfaces.wlp170s0.useDHCP = true;

  # virtualisation.lxd.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings = {
    default-address-pools = [
      {
        base = "172.30.0.0/16"; # mhm, might be too large.
        # bd train network: 172.18.0.0
        size = 24;
      }
    ];
  };

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


  # steam
  environment.systemPackages = with pkgs; [
    # (steam.override { extraPkgs = pkgs: [ mono gtk3 gtk3-x11 libgdiplus zlib ]; nativeOnly = true; }).run
    (steam.override { extraPkgs = pkgs: [ mono gtk3 gtk3-x11 libgdiplus zlib ]; }).run
    # actually non-steam
    acpilight
    # lxd
    docker
    vscode.fhs
  ];

  hardware.opengl.driSupport32Bit = true;
  hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
  hardware.pulseaudio.support32Bit = true;
  # steam end

  # experiment to enable more hardware accel and lower power draw on videos?
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD
      vaapiIntel         # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # printer
  services.printing.enable = true;
  services.printing.drivers = with pkgs; [
    gutenprint
    epson-escpr
    epson-escpr2
  ];


  # this disables nix-env ?
  # nix = {
  #   package = pkgs.nixFlakes; # or versioned attributes like nix_2_7
  #   extraOptions = ''
  #     experimental-features = nix-command flakes
  #   '';
  # };
}
