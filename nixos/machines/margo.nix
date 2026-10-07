# # put here:
# modify config for i3status-rs (battery, network)
# adapt fish/config (greet on tux)
# add /datadisk to fstab
#
# modify startup script:
# - setting background
{ config, lib, pkgs, ... }: with pkgs; rec

{
  imports = [ ../shared/desktops/hyprland-session.nix ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Offload builds to jolly over Tailscale (its nix.sshServe side lives in
  # jolly.nix). The nix-daemon connects as root, hence the dedicated
  # passphrase-less /root/.ssh/nix-builder key. When jolly is unreachable,
  # builds fall back to local after the short ConnectTimeout below.
  nix.distributedBuilds = true;
  nix.buildMachines = [{
    hostName = "jolly.ts.kolai.eu";
    sshUser = "nix-ssh";
    sshKey = "/root/.ssh/nix-builder";
    protocol = "ssh-ng";
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU5RdENIeEpIRWc1cHlqUXlqenlVUFoxS0tzQTFaNTcvZmxzaEdKVlhrOVE=";
    systems = [ "x86_64-linux" "i686-linux" ];
    maxJobs = 16;
    speedFactor = 4;
    supportedFeatures = [ "benchmark" "big-parallel" "kvm" "nixos-test" ];
  }];
  # jolly fetches cache.nixos.org paths itself instead of margo uploading them
  nix.settings.builders-use-substitutes = true;
  # jolly as a LAN cache, preferred over cache.nixos.org (priority 40). Only
  # paths jolly itself substituted carry cache.nixos.org signatures, so its
  # own unsigned builds are not pulled from here.
  nix.settings.extra-substituters = [
    "ssh-ng://nix-ssh@jolly.ts.kolai.eu?ssh-key=/root/.ssh/nix-builder&priority=30&base64-ssh-public-host-key=c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU5RdENIeEpIRWc1cHlqUXlqenlVUFoxS0tzQTFaNTcvZmxzaEdKVlhrOVE="
  ];
  programs.ssh.extraConfig = ''
    Host jolly.ts.kolai.eu
      ConnectTimeout 3
  '';
  networking.networkmanager.wifi.scanRandMacAddress = false;

  services.displayManager = {
    gdm.enable = true;
    defaultSession = "hyprland";
  };

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.gdm-password.enableGnomeKeyring = true;
  programs.ssh.startAgent = lib.mkForce false;

  environment.sessionVariables = {
    HYPRLAND_HOST_CONFIG = "${/home/pars/configs/dotconfig/hypr/margo.lua}";
    HYPRLAND_WAYBAR_CONFIG = "${config.users.users.pars.home}/.config/waybar/margo.jsonc";
    LIBVA_DRIVER_NAME = "iHD";
  };

  system.autoUpgrade = {
    enable = true;
    operation = "boot";
    allowReboot = false;
    channel = "https://nixos.org/channels/nixpkgs-unstable";
  };

  # `i915.enable_psr=1`:  force-enable psr (should be enabled default in >=5.14) to reach deeper suspend states on idle
  # `mem_sleep_default=deep`: 'shutdown' system and go to deep suspension instead of `s2idle`. This trades reduced energy consumption for increased resume time delay.
  # boot.kernelParams = [ "mem_sleep_default=deep" "nvme.noacpi=1" "mitigations=off" "fsck.mode=force" "fsck.repair=yes" "i915.enable_psr=1"];
  boot.kernelParams = [ "fsck.mode=force" "fsck.repair=yes"];
  # boot.kernelParams = [ "mem_sleep_default=deep" ];
  # run `sudo powertop --auto-tune` on startup. Reduces power consumption on idle
  powerManagement.powertop.enable = true;
  # CPU power policy (EPP / platform profile); without it intel_pstate sits on balance_performance
  services.power-profiles-daemon.enable = true;
  # switch to power-saver on battery, back to balanced on AC
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="ACAD", ATTR{online}=="0", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver"
    SUBSYSTEM=="power_supply", KERNEL=="ACAD", ATTR{online}=="1", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced"
  '';

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/ba2ef340-5436-4a5e-a39c-791de5bf38a7";
      fsType = "ext4";
    };

  boot.initrd.luks.devices."crypted".device = "/dev/disk/by-uuid/3b04250a-2b83-4498-a590-c2de44dd7b60";

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/4135-4CBC";
      fsType = "vfat";
    };

  # Disk backing for zswap, stored on the encrypted root filesystem.
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 16 * 1024; # MiB (16 GiB)
  }];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # networking
  networking.hostName = "margo";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  # networking.useDHCP = false; # already set globally in default
  networking.interfaces.wlp170s0.useDHCP = true;
  # networking.useDHCP = true;

  # virtualisation.lxd.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings = {
    default-address-pools = [
      {
        base = "112.30.0.0/16"; # mhm, might be too large.
        # bd train network: 172.18.0.0
        size = 24;
      }
    ];
  };

  # enable touchpad support
  services.libinput = {
    enable = true;
    touchpad.disableWhileTyping = true;
    touchpad.naturalScrolling = true;
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
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
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
    # (steam.override { extraPkgs = pkgs: [
    #     mono
    #     gtk3
    #     gtk3-x11
    #     libgdiplus
    #     zlib
    #     dbus
    #     glib
    #     atk
    #     cairo
    #     pango
    #     fontconfig
    #     libxcb
    #     mesa
    #     libva
    #     intel-media-driver
    #     vaapiIntel
    #     libvdpau-va-gl
    # ]; }).run
    # actually non-steam
    acpilight
    # lxd
    docker
    vscode.fhs
    zotero
  ];

  programs.steam.package = pkgs.steam.override {
    extraPkgs = pkgs: with pkgs; [
        mono
        gtk3
        gtk3-x11
        libgdiplus
        zlib
        dbus
        glib
        atk
        cairo
        pango
        fontconfig
        libxcb
        mesa
        libva
        intel-media-driver
        intel-vaapi-driver
        libvdpau-va-gl
    ];
  };

  programs.steam.enable = true;
  # hardware.graphics.extraPackages = [ pkgs.amdvlk ]; # Vulkan driver for AMD
  hardware.steam-hardware.enable = true; # additional controller support

  services.pulseaudio.support32Bit = true;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "steam"
    "steam-original"
    "steam-unwrapped"
    "steam-run"
  ];
  # steam end

  # experiment to enable more hardware accel and lower power draw on videos?
  nixpkgs.config.packageOverrides = pkgs: {
    intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
  };
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
    extraPackages = with pkgs; [
      intel-media-driver # LIBVA_DRIVER_NAME=iHD
      # vaapiIntel         # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
      # vaapiVdpau
      intel-vaapi-driver
      vaapi-intel-hybrid
      libva-vdpau-driver
      libvdpau-va-gl
    ];
  };

  # firmware updates
  services.fwupd.enable = true;

  # printer
  services.printing.enable = true;
  services.printing.drivers = with pkgs; [
    gutenprint
    epson-escpr
    epson-escpr2
  ];

  environment.etc."X11/xorg.conf.d/20-intel.conf" = {
    text = ''
      Section "Device"
        Identifier "Intel Graphics"
        Driver "intel"
        Option "TearFree" "true"
        Option "AccelMethod" "sna"
        Option "SwapbuffersWait" "true"
      EndSection
    '';
  };


  # this disables nix-env ?
  # nix = {
  #   package = pkgs.nixFlakes; # or versioned attributes like nix_2_7
  #   extraOptions = ''
  #     experimental-features = nix-command flakes
  #   '';
  # };

  # Logitech receiver tools and the Solaar peripheral manager.
  hardware.logitech.wireless.enable = true;
  programs.solaar.enable = true;
}
