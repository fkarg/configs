{ pkgs, ... }:

let
  # Linux 7.2 supports the MT7927 (Filogic 380) in-tree, so the out-of-tree
  # modules this file used to build are gone. What 7.2 covers, verified against
  # the kernel source rather than release notes:
  #
  #   * WiFi: mt7925e claims PCI 14c3:7927 (mt76/mt7925/pci.c) and requests
  #     mediatek/mt7927/WIFI_{RAM_CODE_MT6639_2_1,MT6639_PATCH_MCU_2_1_hdr}.bin
  #     (mt76/mt792x.h) — both of which linux-firmware ships as of 20260622.
  #   * L1 ASPM: disabled in-tree and unconditionally for MT7927 hardware
  #     ("ASPM L1 causes unreliable WFDMA register access", mt7925/pci.c), so
  #     the udev link/l1_aspm rule that used to live here is redundant.
  #   * Bluetooth: btusb/btmtk have driven the BT function since 7.1, and
  #     jolly's controller (0489:e13a, ASUS ROG Crosshair X870E Hero) is in
  #     btmtk's in-tree btmtk_mt6639_devs table. The out-of-tree BT patch set
  #     only added an HP EliteMini ID we don't have.
  #
  # Dropping the out-of-tree build is also what unblocks upgrades at all: its
  # pinned mt76 snapshot stopped compiling against 7.2 (mac80211 renamed
  # IEEE80211_EML_CAP_EMLSR_{PADDING,TRANSITION}_DELAY to IEEE80211_EML_CAP_EML_*),
  # which failed every nixos-upgrade run from 2026-08-05 onward.
  #
  # The upstream flake stays fetched for exactly one thing: the BT firmware
  # blob, which is still not redistributable via linux-firmware.
  mt7927NixosSrc = builtins.fetchTarball {
    url = "https://github.com/cmspam/mt7927-nixos/archive/a391d59fe4e6ad4be6a17cbc3aea29d564137c05.tar.gz";
    sha256 = "1jsh796w7jsqc9y5431br0j6ll7y7s1zmrfywbrskz6q03r2fwim";
  };
  mt7927DkmsSrc = builtins.fetchTarball {
    url = "https://github.com/jetm/mediatek-mt7927-dkms/archive/ad1f3e4d19fe540aaa1f449ddba86c65db9bfc82.tar.gz";
    sha256 = "0kbpyrjqc0i228rqj2hvd7yln0dhh0bk3q6lqcz62zggjs2z0xhr";
  };
  mt7927Flake = import (mt7927NixosSrc + "/flake.nix");
  mt7927 = mt7927Flake.outputs {
    self = mt7927;
    nixpkgs = { legacyPackages.x86_64-linux = pkgs; };
    mediatek-mt7927-dkms = mt7927DkmsSrc;
  };

  # BT_RAM_CODE_MT6639_2_1_hdr.bin is stuck behind MediaTek's redistribution
  # sign-off, so linux-firmware ships the mediatek/mt7927/WIFI_* blobs but not
  # this one. Upstream's `firmware` package extracts it from the ASUS driver zip
  # — that derivation is dontUnpack and never compiles against a kernel, so it
  # survives kernel bumps that break the module builds.
  #
  # Two reasons to re-home rather than use the package directly:
  #   1. Path. Upstream installs to mediatek/mt6639/, but btmtk requests it from
  #      mediatek/mt7927/ (FIRMWARE_MT7927 in btmtk.h). Without the move the
  #      controller enumerates but stays DOWN at 00:00:00:00:00:00 and BlueZ
  #      reports "No default controller available".
  #   2. Scope. The package also installs the two mediatek/mt7927/WIFI_* blobs.
  #      hardware.firmware merges its inputs with ignoreCollisions = true, where
  #      the first list entry silently wins, so pulling the whole package in
  #      would shadow linux-firmware's WiFi blobs with ASUS-extracted copies.
  #      Take the single file we actually need.
  mt7927BtFirmware = pkgs.runCommand "mt7927-bt-firmware" { } ''
    src=${mt7927.packages.x86_64-linux.firmware}/lib/firmware/mediatek/mt6639/BT_RAM_CODE_MT6639_2_1_hdr.bin
    install -Dm644 "$src" "$out/lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin"
  '';
in
{
  hardware.firmware = [ mt7927BtFirmware ];
}
