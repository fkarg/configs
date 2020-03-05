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

  # Optional:
  boot.kernelPackages = pkgs.linuxPackages_latest;


  # enable networkmanager:
  networking.networkmanager.enable = true;

  # this needs to be set globally, and activated for each interface seperately.
  networking.useDHCP = false;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    autorun = true;

    layout = "de";
    xkbVariant = "neo";

    desktopManager = {
      default = "none";
      xterm.enable = false;
    };

    windowManager.default = "i3";
    windowManager.i3 = {
      enable = true;
      extraPackages = with pkgs; [
        dmenu
        sysfsutils
        i3status-rust
        i3lock-fancy
      ];
    };

    displayManager.auto.enable = false;
    displayManager.auto.user = "pars";

  };


}

