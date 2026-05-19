# jolly - AMD Ryzen / RTX 3070 desktop, recovery-stable Wayland/Xorg setup
{ config, lib, pkgs, ... }:

{
  imports = [
    ./default.nix
    ../programs.nix
    ../pars.nix
    ../shared/desktops/hyprland-session.nix
    ../shared/hardware/mediatek-mt7927.nix
    ../shared/programs/steam-defaults.nix
  ];

  networking.hostName = "jolly";

  # GRUB generation labels use system.nixos.label instead of the systemd-boot
  # "version" field. Keep the kernel visible in the generation selector.
  system.nixos.label = "${config.system.nixos.version}-linux-${config.boot.kernelPackages.kernel.version}";

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

  # Keep the default generation on the kernel line that is known to reach GNOME
  # on this host. Newer kernels are available as explicit test specialisations.
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
    "lz4"
  ];
  boot.initrd.supportedFilesystems = [ "vfat" "ext4" ];
  boot.initrd.systemd.services.initrd-switch-root.description = "Switch Root";
  boot.initrd.systemd.services.copy-luks-keyfile = {
    after = lib.mkForce [ ];
    requires = lib.mkForce [ ];
    requiredBy = [ "systemd-cryptsetup@cryptroot.service" ];
    before = [ "systemd-cryptsetup@cryptroot.service" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig.TimeoutSec = 70;
    script = lib.mkForce ''
      mkdir -p /tmp/usbkey
      echo "copy-luks-keyfile: starting USB/removable search..."
      udevadm settle --timeout=15 || true

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
        udevadm settle --timeout=2 || true

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
    configurationLimit = 1;
    extraEntries = ''
      menuentry "NixOS - Known-good fallback generation 8 (Linux 6.12.89)" --class nixos {
        search --set=drive1 --fs-uuid DC22-8B46
        linux ($drive1)//kernels/ss16kh3phklqxgn1dpaa8bwz14wwp84c-linux-6.12.89-bzImage init=/nix/store/5j58nn0b768qlxa3f408k8b3s2pa86j6-nixos-system-jolly-26.05pre998534.d233902339c0/init zswap.enabled=1 zswap.compressor=lz4 zswap.max_pool_percent=25 systemd.log_level=info loglevel=4 root=fstab loglevel=4 lsm=landlock,yama,bpf
        initrd ($drive1)//kernels/kxny1jr30pbfigdjxlyaqp172h4h160d-initrd-linux-6.12.89-initrd
      }
    '';
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.generic-extlinux-compatible.enable = false;

  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  specialisation.manual-unlock.configuration = {
    boot.loader.grub.configurationName = "Manual unlock";
    boot.initrd.systemd.services.copy-luks-keyfile = {
      enable = lib.mkForce false;
      requiredBy = lib.mkForce [ ];
      before = lib.mkForce [ ];
    };
    boot.initrd.luks.devices."cryptroot".keyFileTimeout = lib.mkForce 1;
  };

  specialisation.diagnostic.configuration = {
    boot.loader.grub.configurationName = "Diagnostic verbose";
    boot.kernelParams = [
      "ignore_loglevel"
      "log_buf_len=16M"
      "systemd.log_level=debug"
      "systemd.show_status=1"
      "rd.systemd.show_status=1"
    ];
  };

  specialisation.kernel-6-18.configuration = {
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_18;
    boot.loader.grub.configurationName = "Kernel test - Linux 6.18";
  };

  specialisation.mt7927-latest-bt-usb-retry.configuration = {
    boot.loader.grub.configurationName = "MT7927 Bluetooth USB retry - TEST";
    boot.kernelParams = [
      "usbcore.old_scheme_first=1"
      "usbcore.initial_descriptor_timeout=10000"
      "usbcore.quirks=13d3:3588:k"
      "btusb.enable_autosuspend=0"
    ];
    systemd.services.reset-mt7927-bluetooth-usb = {
      description = "Reset MT7927 Bluetooth USB port before BlueZ";
      requiredBy = [ "bluetooth.service" ];
      before = [ "bluetooth.service" ];
      path = [ pkgs.coreutils pkgs.systemd ];
      serviceConfig.Type = "oneshot";
      script = ''
        port=/sys/bus/usb/devices/usb1/1-0:1.0/usb1-port9
        if [ -e "$port/disable" ]; then
          echo 1 > "$port/disable" || true
          sleep 2
          echo 0 > "$port/disable" || true
          udevadm settle --timeout=10 || true
        fi
      '';
    };
  };

  virtualisation.docker.enable = true;

  hardware.i2c.enable = false;
  services.hardware.openrgb.enable = false;

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
  programs.ssh.askPassword = lib.mkForce "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";

  # TTY fallback if GDM or GNOME/COSMIC are unhappy. Hyprland is installed as a
  # selectable GDM session by ../shared/desktops/hyprland-session.nix.
  programs.sway = {
    enable = true;
    extraOptions = [ "--unsupported-gpu" ];
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
  hardware.graphics.enable32Bit = true;
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
  ];
}