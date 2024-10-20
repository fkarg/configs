# General system setup routines.
# partial startup script:
# - starting redshift
# - starting xcompmgr
# - swapoff -a
# - xset -dpms
# - xset -s off
# - xset m 10/1 1

{ config, pkgs, ... }:

{
  # Use the GRUB 2 boot loader.
  # boot.loader.grub.enable = true;
  # boot.loader.grub.version = 2;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  # boot.loader.grub.device = ??? # or "nodev" for efi only

  # boot.extraModulePackages = with config.boot.kernelPackages; [ rtl88x2bu ]; # currently broken with latest kernel

  # Optional:
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # automatically run `nix-store --optimize`
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };


  # enable networkmanager:
  networking.networkmanager.enable = true;

  # this needs to be set globally, and activated for each interface seperately.
  networking.useDHCP = false;

  # dedicate part of RAM as compressed SWAP space
  zramSwap.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "neo";
  };


  # Enable sound.
  # sound.enable = true;
  # sound.mediaKeys.enable = true;  # enable audio control through default media keys
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.package = pkgs.pulseaudioFull;


  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # automatically set LD_LIBRARY_PATH
  # hardware.opengl.setLdLibraryPath = true;

  services.displayManager = {
    defaultSession = "none+i3";
    autoLogin = {
      enable = true;
      user = "pars";
    };
  };

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;

    desktopManager.xterm.enable = false;

    autorun = true;

    xkb = {
      layout = "de";
      variant = "neo";
    };

    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        dmenu
        sysfsutils
        i3status-rust
        i3lock-fancy
      ];
    };
  };

  services.openssh = {
    enable = true;
    startWhenNeeded = true;
  };
  programs.ssh ={
    startAgent = true;
    forwardX11 = true;
  };


  services.upower.enable = true;

  # services.resolved.enable = true;
  # services.resolved.fallbackDns = [
  networking.networkmanager.appendNameservers = [
    "208.67.220.220"
    "208.67.222.222"
    "8.8.8.8"
  ];

  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    channel = "https://nixos.org/channels/nixpkgs-unstable";
  };
}
