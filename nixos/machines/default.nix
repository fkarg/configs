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
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  # boot.loader.grub.device = ??? # or "nodev" for efi only

  # boot.extraModulePackages = with config.boot.kernelPackages; [ rtl88x2bu ]; # currently broken with latest kernel

  # Optional:
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  # boot.kernelPackages = pkgs.linuxPackages_5_12_13;


  # enable networkmanager:
  networking.networkmanager.enable = true;

  # this needs to be set globally, and activated for each interface seperately.
  networking.useDHCP = false;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Enable sound.
  sound.enable = true;
  sound.mediaKeys.enable = true;  # enable audio control through default media keys
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.package = pkgs.pulseaudioFull;

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;

    desktopManager.xterm.enable = false;

    autorun = true;

    layout = "de";
    xkbVariant = "neo";

    # deprecated ?
    # windowManager.default = "i3";

    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        dmenu
        sysfsutils
        i3status-rust
        i3lock-fancy
      ];
    };

    displayManager.defaultSession = "none+i3";
    displayManager.autoLogin = {
      enable = true;
      user = "pars";
    };

  };

  services.openssh.enable = true;
  services.openssh.startWhenNeeded = true;

  services.upower.enable = true;
}
