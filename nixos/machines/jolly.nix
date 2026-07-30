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
    # The nvidia driver build shells out to jq; add it to nativeBuildInputs for
    # both kernel sets nixos-rebuild builds here — latest (default boot) and 6.18
    # (the kernel-6-18 fallback specialisation below).
    (final: prev:
      let
        withJqNvidia = kpkgs: kpkgs.extend (_: kprev: {
          nvidiaPackages = kprev.nvidiaPackages.extend (_: nprev: {
            latest = nprev.latest.overrideAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.jq ];
            });
          });
        });
      in
      {
        linuxPackages_latest = withJqNvidia prev.linuxPackages_latest;
        linuxPackages_6_18 = withJqNvidia prev.linuxPackages_6_18;
      })
  ];

  # Default to linuxPackages_latest (7.1.x). We used to pin 7.0, but nixpkgs
  # EOL-removed it. The out-of-tree MT7927 driver (shared/hardware/mediatek-
  # mt7927.nix) was rebased onto the 7.1.x mt76 tarball and now compiles against
  # 6.17–7.1, so latest works again. In-tree mt7925e MT7927 support lands in 7.2
  # (final ~late Aug 2026); once nixpkgs ships a 7.2 kernel we can drop the
  # out-of-tree module for wifi entirely (BT still needs the manual firmware blob
  # until it merges into linux-firmware). The kernel-6-18 specialisation below is
  # a fallback on the 6.18 LTS line if a latest bump breaks the wifi build.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    # "fsck.mode=force"
    # "fsck.repair=yes"
    "usbcore.autosuspend=-1"
    "systemd.log_level=info"
    "loglevel=4"
    # MT7927 BT controller enumerates fine; its only failure was the missing
    # firmware blob, fixed by the mediatek/mt7927 path re-home in
    # shared/hardware/mediatek-mt7927.nix. Keep autosuspend off for BT stability.
    "btusb.enable_autosuspend=0"
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

  # Root is LUKS, unlocked by a USB keyfile inside the initrd, so the
  # bootloader runs before the store is readable and every generation's
  # kernel+initrd must live on an unencrypted partition. That's the 8GB ext4
  # /boot (carved out of swap, 2026-07); the 1GB ESP is mounted at /boot/efi
  # and holds only the GRUB EFI binary. See docs/jolly.md "Boot partition &
  # rollback depth" for the layout and the runbook that created it.
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    # Capacity guard for the 8GB ext4 /boot, not a retention policy (that's
    # nix.gc, 90d). Each generation stages up to ~220MB worst-case (default
    # initrd + manual-unlock specialisation initrd + 6.18 fallback
    # kernel+initrd; unchanged files are shared between generations), so 30
    # fits with ample headroom. Deeper rollback than the menu shows:
    # nixos-rebuild --rollback re-stages on demand. See docs/jolly.md.
    configurationLimit = 30;
    # Only the auto-generated generation list is trustworthy for rollback — it's
    # GC-tracked. A hand-written menuentry pinning specific /nix/store paths rots
    # the moment GC collects them, so we don't keep one. Windows entries are safe:
    # they chainload firmware boot managers by fs-uuid, nothing in the nix store.
    extraEntries = ''
      menuentry "Windows (internal ESP)" --class windows {
        # Match the Windows ESP by fs-uuid, not label: GRUB's `search --label`
        # is case-sensitive and the FAT label is upper-case SYSTEM (two other
        # partitions are labelled EFI, so labels are ambiguous here anyway).
        search --no-floppy --set=win_esp --fs-uuid 4E4C-51EE
        if [ -f ($win_esp)/EFI/Microsoft/Boot/bootmgfw.efi ]; then
          chainloader ($win_esp)/EFI/Microsoft/Boot/bootmgfw.efi
        else
          echo "Windows boot manager missing on internal ESP 4E4C-51EE"
          sleep 5
        fi
      }
      menuentry "Windows (via USB EFI)" --class windows {
        # Temporary boot path: the internal Windows ESP is currently not
        # bootable, but the USB ESP labelled EFI still has a working Windows
        # boot manager/BCD store for this install.
        search --no-floppy --set=win_usb_esp --fs-uuid 67E3-17ED
        if [ -f ($win_usb_esp)/EFI/Microsoft/Boot/bootmgfw.efi ]; then
          chainloader ($win_usb_esp)/EFI/Microsoft/Boot/bootmgfw.efi
        else
          echo "Windows USB boot manager missing on ESP 67E3-17ED"
          sleep 5
        fi
      }
    '';
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.generic-extlinux-compatible.enable = false;

  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # Logitech peripheral manager.
  # this pulls in the package 'solaar' plus the udev rules the receiver needs.
  hardware.logitech.wireless.enable = true;

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

  # Fallback kernel on the 6.18 LTS line. Default boot is linuxPackages_latest
  # (7.1.x); if a nixpkgs bump moves latest past what the out-of-tree MT7927
  # driver compiles against (e.g. an unported 7.2 mt76), boot this entry to get
  # wifi back. 6.18 is LTS (EOL ~Dec 2028), so it stays in nixpkgs long-term.
  specialisation.kernel-6-18.configuration = {
    boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_18;
    boot.loader.grub.configurationName = "Fallback - Linux 6.18 LTS";
  };

  virtualisation.docker.enable = true;

  # BOINC distributed computing with NVIDIA GPU compute. Per the services.boinc
  # docs, CUDA needs the NVIDIA driver package in-env and OpenCL needs both that
  # driver and the ocl-icd loader; pinning to config.hardware.nvidia.package
  # keeps the CUDA/OpenCL userspace matched to the loaded kernel module.
  # libglvnd/brotli cover the client runtime. `pars` joins the boinc group so
  # boincmgr can read the RPC auth cookie. Confirm GPU detection in boincmgr's
  # event log after the next boot (jolly is boot-not-switch).
  services.boinc = {
    enable = true;
    extraEnvPackages = (with pkgs; [ ocl-icd libglvnd brotli ])
      ++ [ config.hardware.nvidia.package ];
  };
  users.users.pars.extraGroups = [ "boinc" ];

  # i2c on by default: it has proven stable on its own, and the KVM input-switch
  # bind (Ctrl+Shift+F12 → ddcutil) needs it. The historical full-blackscreen
  # incident on this RTX 3070 required i2c *paired with OpenRGB* — so OpenRGB
  # stays off (that's the half of the combo that actually triggered it), while
  # i2c alone is fine.
  hardware.i2c.enable = true;
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
  programs.ssh.startAgent = lib.mkForce false;
  programs.ssh.askPassword = lib.mkForce "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";

  # TTY fallback if GDM, GNOME, or Hyprland are unhappy. Hyprland is installed as a
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
  # Blacklist the AMD Granite Ridge iGPU. The monitor lives on the NVIDIA dGPU,
  # but with amdgpu loaded aquamarine enumerates the iGPU as a secondary GPU,
  # flags every buffer "multigpu, forcing linear", and repeatedly spins up then
  # tears down its renderer for the iGPU's phantom-connected HDMI port ("no
  # enabled outputs"). That cross-GPU dmabuf path (EGL_BAD_MATCH on import) left
  # individual workspaces stuck at a degraded framebuffer resolution and made
  # newly-spawned windows flash-and-vanish. One GPU = none of that.
  boot.blacklistedKernelModules = [ "nouveau" "amdgpu" ];

  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
    mesa-demos
    vulkan-tools
    wayland-utils
    wlr-randr
    # Drives the Hyprland Ctrl+Shift+F12 KVM bind. Functional only when
    # booted into the `i2c-kvm` specialisation (i2c stays off otherwise).
    ddcutil
    zotero
    # YouTube Music client; autostarted on ws4 by dotconfig/hypr/startup-apps.sh.
    pear-desktop
    # btop's GPU panel dlopens libnvidia-ml.so.1; the plain btop from the shared
    # package lists lacks /run/opengl-driver/lib in its runpath, so NVML never
    # loads and the GPU section silently disappears. The cuda variant stamps the
    # driver runpath in; hiPrio wins the bin/btop collision.
    (lib.hiPrio btop-cuda)
    # boincmgr silently exits 1 on the GTK Wayland backend during NVIDIA EGL
    # init; it runs fine under Xwayland, so shadow it with a wrapper that
    # forces the x11 backend. hiPrio wins the bin/boincmgr collision with the
    # plain boinc package that services.boinc puts in systemPackages.
    (lib.hiPrio (pkgs.writeShellScriptBin "boincmgr" ''
      export GDK_BACKEND=x11
      exec ${pkgs.boinc}/bin/boincmgr "$@"
    ''))
  ];
}
