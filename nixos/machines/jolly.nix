# jolly — AMD Ryzen / RTX 3070 desktop with Wayland
{ config, lib, pkgs, ... }:

{
  imports = [
    ../shared/packages/gaming-compat.nix
    ../shared/programs/steam-defaults.nix
    ../shared/desktops/hyprland-session.nix
  ];

  # Keep jolly on a manually controlled update path until the host baseline
  # is cleaned up and reproducible again.
  system.autoUpgrade.enable = lib.mkForce false;
  services.cron.systemCronJobs = lib.mkForce [
    "0 * * * *      pars  /home/pars/passive_update.sh"
  ];

boot.kernelParams = [
      "fsck.mode=force"
      "fsck.repair=yes"
      "usbcore.autosuspend=-1"
    ];

   boot.loader.systemd-boot.enable = true;
   boot.loader.efi.canTouchEfiVariables = true;

    # Greetd with true auto-login to Hyprland (no password)
    services.greetd.enable = true;
    services.greetd.settings = rec {
      initial_session = {
        command = "${pkgs.hyprland}/bin/start-hyprland";
        user = "pars";
      };
      default_session = initial_session;
    };

   networking.hostName = "jolly";
   virtualisation.docker.enable = true;

   services.xserver.videoDrivers = [ "nvidia" "modesetting" "fbdev" ];

   services.libinput.enable = true;

   hardware.bluetooth.enable = true;
   hardware.bluetooth.powerOnBoot = true;
   services.blueman.enable = true;

   hardware.enableRedistributableFirmware = true;

boot.initrd.kernelModules = [ "mt7925e" "amdgpu" "xhci_pci" "usb_storage" ];

hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      open = true;
      modesetting.enable = true;
      powerManagement.enable = true;
    };

   boot.blacklistedKernelModules = [ "nouveau" ];
   hardware.graphics.enable = true;
   hardware.graphics.enable32Bit = true;
}
