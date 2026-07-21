# Jolly

Documentation and overview for the Jolly Desktop PC build.

## Hardware Specifications

### System Overview

- **CPU**: AMD Ryzen 9 9950X3D 16-Core Processor (32 cores, 64 threads)
- **GPU**: NVIDIA GeForce RTX 3070
- **Motherboard**: ASUS ROG STRIX X870E-E GAMING WIFI (AMD TRX50 chipset)
- **Storage**:
  - Boot NVMe SSD (nvme0n1): 3.6TB total capacity
    - nvme0n1p1: 1GB EFI partition (/boot)
    - nvme0n1p2: 16GB swap partition
    - nvme0n1p3: 3.6TB LUKS-encrypted root partition (mounted as /nix/store)
  - Data NVMe drive (nvme1n1): 1.8TB total capacity
    - nvme1n1p1: 16MB partition
    - nvme1n1p2: 1.8TB partition
    - nvme1n1p3: 743MB partition
  - USB key for LUKS keyfile (LUKS-KEYS): 29.3GB
  - Windows backup drive (Win11): 28.5GB
- **Memory**: Not explicitly specified in documentation

### Key Hardware Components

- **WiFi/BT Chipset**: MEDIATEK MT7927 802.11be 320MHz 2x2 PCIe Wireless Network Adapter
- **Graphics Drivers**: NVIDIA with modesetting support, using KVM AMD modules
- **Audio**: NVIDIA High Definition Audio Controller + USB audio DAC as main output device
- **Bluetooth**: Enabled with power-on boot and Blueman manager

## Configuration Details

### Operating System

- **Base OS**: NixOS 26.05pre998534.d233902339c0 (Yarara)
- **Desktop Environment**: GDM session chooser with GNOME and Hyprland available; Sway remains a TTY-launchable fallback
- **Display Manager**: GDM; previous greetd auto-login is intentionally not enabled
- **Bootloader**: GRUB EFI

### System Settings

- **Auto-upgrade Policy**: Enabled but uses "boot" operation instead of live switching
- **Kernel Parameters**:
  - `fsck.mode=force`
  - `fsck.repair=yes`
  - `usbcore.autosuspend=-1`
- **NVIDIA Configuration**:
  - Uses latest NVIDIA driver package matching the selected kernel
  - Open NVIDIA drivers enabled
  - Modesetting enabled
  - Power management enabled
- **RGB Control**:
  - OpenRGB service enabled
  - i2c support enabled
  - `openrgb-with-all-plugins` installed

### Network Interfaces

- **Primary LAN**: enp10s0
- **USB Ethernet Adapter**: enp15s0u5u3u3 (for backup/secondary connection)
- **WiFi**: MEDIATEK MT7927 WiFi 7 adapter with pinned `cmspam/mt7927-nixos` support module

### Storage & Boot

- **Boot Partition**: nvme0n1p1 (1GB FAT32 EFI)
- **Swap**: nvme0n1p2 (16GB)
- **Root Filesystem**: nvme0n1p3 (LUKS encrypted ext4 partition, mounted as /nix/store)
- **LUKS Boot Logic**: Custom initrd systemd service that searches for LUKS keyfile on USB stick
  - Searches for "LUKS-KEYS" labeled USB device
  - Falls back to interactive passphrase when key is absent

### Security & Boot

- **Boot Logic**: Uses custom LUKS USB key boot logic with systemd stage-1 configuration
- **Root Password**: Recovery-era weakened password (to be hardened)
- **SSH Policy**: Not explicitly specified in current recovery configuration

## Boot partition & rollback depth

### The constraint

Root (p3) is LUKS, unlocked by a USB keyfile *inside the initrd*. The bootloader
runs before that unlock, so every bootable menu entry's kernel+initrd must live
on an unencrypted filesystem GRUB can read. Historically that was the 1GB ESP
(`/boot`), which fits only ~3-4 generations at jolly's ~220MB/generation
(default initrd + manual-unlock specialisation initrd + 6.18 fallback
kernel+initrd; consecutive generations share unchanged files, so real growth is
slower). `boot.loader.grub.configurationLimit` is the ESP-capacity guard — it
is *not* the generation-retention policy (that's `nix.gc`, 90d, in
`shared/base-system.nix`). Deeper rollback than the menu shows is always
available via `sudo nixos-rebuild --rollback boot`, which re-stages on demand.

### Runbook: carve an 8GB ext4 /boot out of swap (live, no installer USB)

Target layout — p1 and p3 are **never modified**; only swap space is
reorganised. Everything below runs on the live system; keep an installer USB
plugged in as a parachute but expect not to need it.

| partition | before | after |
|---|---|---|
| p1 ESP `DC22-8B46` | 1GB, is `/boot` (kernels+grub+EFI) | untouched → remounted `/boot/efi`, holds only the GRUB EFI binary |
| p2 swap 16GB | sectors 2099200–35653631 | 8GB ext4 `/boot` (2099200–18876415) + 8GB swap (18876416–35653631) |
| p3 LUKS root | sectors 35653632–end | untouched |

Sector math assumes 512-byte logical sectors — verify first:
`sudo blockdev --getss /dev/nvme0n1` must print `512`. Both new partitions are
1MiB-aligned and the new swap ends flush against p3 (18876416 + 16777216 =
35653632 = p3 start).

Swap sizing rationale: 96GB RAM, no hibernation (never fit in 16GB anyway, and
hibernate-through-LUKS-USB-keyfile is its own project). Swap only backs zswap
writeback of cold compressed pages, so 8GB is generous; 8GB /boot ≈ 36+ menu
entries, making the 90d GC the binding constraint again.

1. **Preflight** — confirm sector size and current table match the values above:

   ```sh
   sudo blockdev --getss /dev/nvme0n1        # must be 512
   cat /sys/block/nvme0n1/nvme0n1p2/start    # must be 2099200
   cat /sys/block/nvme0n1/nvme0n1p2/size     # must be 33554432
   cat /sys/block/nvme0n1/nvme0n1p3/start    # must be 35653632
   ```

2. **Detach swap and repartition** (p1/p3 stay busy/mounted — fine, they are
   not touched; parted updates the kernel per-partition):

   ```sh
   sudo swapoff /dev/nvme0n1p2
   sudo parted /dev/nvme0n1 rm 2
   sudo parted /dev/nvme0n1 mkpart boot ext4 2099200s 18876415s
   sudo parted /dev/nvme0n1 mkpart swap linux-swap 18876416s 35653631s
   lsblk /dev/nvme0n1   # note the assigned numbers; parted reuses the lowest
                        # free number, so expect boot=p2, swap=p4 — verify!
   ```

3. **Create filesystems.** Reuse the old swap UUID so the host-local
   `hardware-configuration.nix` `swapDevices` entry stays valid; capture the
   new ext4 UUID for step 4:

   ```sh
   sudo mkfs.ext4 -L nixboot /dev/nvme0n1p2          # adjust if numbering differs
   sudo mkswap -U 75d7c2a7-c8e5-4854-8795-d8da19f2a20f /dev/nvme0n1p4
   sudo swapon /dev/nvme0n1p4
   sudo blkid /dev/nvme0n1p2                          # note UUID=<BOOT-UUID>
   ```

4. **Rewire the mounts** in `/etc/nixos/hardware-configuration.nix` — replace
   the `fileSystems."/boot"` block with:

   ```nix
   fileSystems."/boot" =
     { device = "/dev/disk/by-uuid/<BOOT-UUID>";
       fsType = "ext4";
     };

   fileSystems."/boot/efi" =
     { device = "/dev/disk/by-uuid/DC22-8B46";
       fsType = "vfat";
       options = [ "fmask=0022" "dmask=0022" ];
     };
   ```

   In `nixos/machines/jolly.nix`: set
   `boot.loader.efi.efiSysMountPoint = "/boot/efi";` next to
   `boot.loader.efi.canTouchEfiVariables`, and raise
   `boot.loader.grub.configurationLimit` (30 fits comfortably in 8GB). Do this
   **only now** — raising the limit while `/boot` is still the 1GB ESP refills
   it and reproduces the "No space left on device" bootloader failure.

5. **Move the mounts and install** — the old ESP keeps its working GRUB until
   the rebuild atomically reinstalls it pointing at the new `/boot`:

   ```sh
   sudo umount /boot
   sudo mkdir -p /boot && sudo mount /dev/nvme0n1p2 /boot
   sudo mkdir -p /boot/efi && sudo mount /dev/disk/by-uuid/DC22-8B46 /boot/efi
   sudo nixos-rebuild boot
   ```

6. **Verify, reboot, clean up.** Check `/boot/kernels` and `/boot/grub` exist
   on the ext4 partition and `ls /boot/efi/EFI` still shows the GRUB entry.
   Reboot, confirm the menu lists generations. Then free the old staging area
   on the ESP: `sudo rm -rf /boot/efi/kernels /boot/efi/grub` (the EFI binary
   under `/boot/efi/EFI/` is all the ESP needs; `/boot/grub` on ext4 is the
   live config).

If anything goes wrong before step 5's rebuild succeeds, nothing has changed
for booting: the ESP is intact and the system boots exactly as before (swap may
need `swapon` after a crash mid-procedure). Only a failure *during* the GRUB
reinstall itself needs the installer-USB parachute: boot it, unlock p3
(`cryptsetup open /dev/nvme0n1p3 cryptroot`), mount root + `/boot` + ESP, and
re-run `nixos-enter --root /mnt -c 'nixos-rebuild boot'`.

## Resources

### MT7927 WiFi/BT

- https://www.linaro.org/blog/from-replace-it-with-intel-to-upstream-bringing-mediatek-bluetooth-wifi-7-to-linux/
- https://jetm.github.io/blog/posts/mt7927-wifi-making-it-work/
- https://github.com/jetm/mediatek-mt7927-dkms

### Additional References

- [Jolly Hardening Plan](jolly-hardening-plan.md) - Detailed stabilization plan for this system
- [NixOS Configuration](../nixos/machines/jolly.nix) - Main system configuration file
- [System Variables](../vars/jolly.yml) - System-specific variables and settings

## Current Status

This system is currently in a recovery state with:

- Configuration now versioned in `nixos/machines/jolly.nix`
- `/etc/nixos/configuration.nix` reduced to local imports and `system.stateVersion`
- GDM-based session chooser instead of greetd auto-login
- Hyprland available as a selectable session, with GNOME kept as the graphical fallback
- WiFi/BT support via pinned MT7927 driver module
- Recovery-focused upgrade policy
- OpenRGB/AuraSync support enabled through OpenRGB and i2c

Adapt accordingly.
