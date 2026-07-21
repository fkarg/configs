{ pkgs, ... }:

let
  # Out-of-tree MT7927 driver. The mt76 snapshot was rebased onto the 7.1.x
  # kernel tarball and now compiles against Linux 6.17–7.1 (a pre-7.1 action-
  # frame compat patch bridges the mac80211 ieee80211_mgmt union change; an
  # airoha_offload.h stub bridges 6.17–6.18). jolly's default kernel is
  # linuxPackages_latest with a 6.18 LTS fallback — see boot.kernelPackages in
  # machines/jolly.nix. Both projects go obsolete for wifi once in-tree mt7925e
  # MT7927 support ships (Linux 7.2). Pinned to specific commits since cmspam
  # auto-updates its mt76 pin on every upstream stable release.
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

  # Upstream firmware package installs the BT RAM code under
  # mediatek/mt6639/, but the patched btusb driver requests it from
  # mediatek/mt7927/ (kernel log: "Direct firmware load for
  # mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin failed with error -2").
  # Without it the controller enumerates but stays DOWN at address
  # 00:00:00:00:00:00 and BlueZ reports "No default controller available".
  # Re-home the blob into the path the driver actually probes.
  mt7927BtFirmwarePathFix = pkgs.runCommand "mt7927-bt-firmware-mt7927-path" { } ''
    src=${mt7927.packages.x86_64-linux.firmware}/lib/firmware/mediatek/mt6639/BT_RAM_CODE_MT6639_2_1_hdr.bin
    install -Dm644 "$src" "$out/lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin"
  '';
in
{
  imports = [ mt7927.nixosModules.default ];

  hardware.mediatek-mt7927 = {
    enable = true;
    enableWifi = true;
    enableBluetooth = true;
    disableAspm = true;
  };

  hardware.firmware = [ mt7927BtFirmwarePathFix ];
}