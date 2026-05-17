# jolly - AMD Ryzen / RTX 3070 desktop, recovery-stable Wayland/Xorg setup
{ config, lib, pkgs, ... }:

{
  imports = [
    ./default.nix
    ../programs.nix
    ../pars.nix
    ../shared/desktops/hyprland-session.nix
    ../shared/hardware/mediatek-mt7927.nix
  ];

  networking.hostName = "jolly";

  # Keep automatic upgrades, but never live-switch the graphical/NVIDIA stack
  # out from under a running desktop session.
  system.autoUpgrade = {
    enable = lib.mkForce true;
    operation = "boot";
    allowReboot = false;
  };
  services.cron.systemCronJobs = lib.mkForce [ ];

  nixpkgs.overlays = [
    (final: prev: {
      linuxPackages_latest = prev.linuxPackages_latest.extend (_: kprev: {
        nvidiaPackages = kprev.nvidiaPackages.extend (_: nprev: {
          latest = nprev.latest.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.jq ];
          });
        });
      });
    })
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "fsck.mode=force"
    "fsck.repair=yes"
    "usbcore.autosuspend=-1"
    "systemd.log_level=info"
    "loglevel=4"
  ];

  # Robust LUKS keyfile discovery for a removable USB key in systems with many
  # disks and multiple USB devices attached. The cryptroot UUID stays in the
  # generated /etc/nixos/hardware-configuration.nix.
  boot.initrd.kernelModules = lib.mkBefore [
    "xhci_pci"
    "usb_storage"
    "uas"
    "sd_mod"
    "vfat"
    "nls_cp437"
    "nls_iso8859_1"
  ];
  boot.initrd.supportedFilesystems = [ "vfat" "ext4" ];
  boot.initrd.systemd.services.copy-luks-keyfile = {
    before = [ "systemd-cryptsetup@cryptroot.service" ];
    serviceConfig.TimeoutSec = 70;
    script = lib.mkForce ''
      mkdir -p /tmp/usbkey
      echo "copy-luks-keyfile: starting USB/removable search..."

      try_key_device() {
        dev="$1"
        [ -b "$dev" ] || return 1

        for fstype in auto vfat ext4; do
          umount /tmp/usbkey 2>/dev/null || true

          if [ "$fstype" = auto ]; then
            mount -o ro "$dev" /tmp/usbkey 2>/dev/null || continue
          else
            mount -o ro -t "$fstype" "$dev" /tmp/usbkey 2>/dev/null || continue
          fi

          if [ -f /tmp/usbkey/luks-keyfile ]; then
            cp /tmp/usbkey/luks-keyfile /run/luks-keyfile
            chmod 400 /run/luks-keyfile
            umount /tmp/usbkey 2>/dev/null || true
            echo "copy-luks-keyfile: keyfile found on $dev"
            exit 0
          fi

          umount /tmp/usbkey 2>/dev/null || true
        done

        return 1
      }

      candidate_devices() {
        for dev in \
          /dev/disk/by-label/LUKS-KEYS \
          /dev/disk/by-label/LUKS_KEYS \
          /dev/disk/by-id/usb*-part* \
          /dev/disk/by-id/usb* \
          /dev/disk/by-path/*usb*-part* \
          /dev/disk/by-path/*usb* \
          /dev/disk/by-path/*USB*-part*; do
          [ -e "$dev" ] && echo "$dev"
        done

        for sysdev in /sys/block/*; do
          [ -f "$sysdev/removable" ] || continue
          [ "$(cat "$sysdev/removable" 2>/dev/null)" = 1 ] || continue

          name="$(basename "$sysdev")"
          for part in "$sysdev"/"$name"*; do
            [ -f "$part/partition" ] || continue
            [ -b "/dev/$(basename "$part")" ] && echo "/dev/$(basename "$part")"
          done

          [ -b "/dev/$name" ] && echo "/dev/$name"
        done
      }

      for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
        for dev in $(candidate_devices); do
          try_key_device "$dev"
        done

        echo "copy-luks-keyfile: searching for USB key... (attempt $attempt/30)"
        sleep 2
      done

      echo "copy-luks-keyfile: keyfile not found, will prompt for password"
    '';
  };
  boot.initrd.luks.devices."cryptroot".keyFileTimeout = 65;

  # GRUB keeps the large kernel/initrd artifacts off the small EFI system
  # partition, unlike the previous systemd-boot setup on this host.
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.generic-extlinux-compatible.enable = false;

  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  virtualisation.docker.enable = true;

  hardware.i2c.enable = true;
  boot.kernelModules = [ "i2c-dev" ];
  services.hardware.openrgb.enable = true;

  services.pipewire.wireplumber.extraConfig."51-swap-analog-stereo" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          { "node.name" = "~alsa_output.*analog-stereo"; }
        ];
        actions.update-props."audio.position" = [ "FR" "FL" ];
      }
    ];
  };

  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = false;
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.monitorSection = ''
    HorizSync 30-240
    VertRefresh 48-144
    Modeline "5120x1440_60.00" 623.65 5120 5488 6048 6976 1440 1441 1444 1490 -HSync +Vsync
    Option "PreferredMode" "5120x1440_60.00"
  '';
  services.xserver.screenSection = ''
    Option "ModeValidation" "AllowNonEdidModes, NoMaxPClkCheck, NoEdidMaxPClkCheck"
    SubSection "Display"
      Depth 24
      Modes "5120x1440_60.00"
    EndSubSection
  '';

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.desktopManager.cosmic.enable = true;
  programs.ssh.startAgent = lib.mkForce false;

  # TTY fallback if GDM or GNOME/COSMIC are unhappy. Hyprland is installed as a
  # selectable GDM session by ../shared/desktops/hyprland-session.nix.
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      foot
      swaylock
      swayidle
      swaybg
      waybar
      wmenu
      grim
      slurp
      wl-clipboard
      xwayland
    ];
  };

  programs.firefox.enable = true;
  services.printing.enable = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.libinput.enable = true;

  services.xserver.videoDrivers = [ "nvidia" "modesetting" ];
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = false;
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    powerManagement.enable = true;
  };
  boot.blacklistedKernelModules = [ "nouveau" ];

  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
    mesa-demos
    vulkan-tools
    wayland-utils
    wlr-randr
    openrgb-with-all-plugins
  ];

  documentation.nixos.enable = false;
  documentation.man.enable = false;
  documentation.info.enable = false;
}