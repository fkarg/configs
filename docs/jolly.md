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
- **Desktop Environment**: GDM session chooser with GNOME, COSMIC, XFCE, and Hyprland available
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
- Hyprland available as a selectable session, not forced at boot
- WiFi/BT support via pinned MT7927 driver module
- Recovery-focused upgrade policy
- OpenRGB/AuraSync support enabled through OpenRGB and i2c

Adapt accordingly.
