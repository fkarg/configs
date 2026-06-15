{ pkgs, ... }:

let
  mt7927NixosSrc = builtins.fetchTarball {
    url = "https://github.com/cmspam/mt7927-nixos/archive/af666e087bb31b1c59906a9a0ec9208703933b06.tar.gz";
    sha256 = "1bw33nhrm0ky2z9f0s376g642yl7zxsbcpqpc89w9505hrm0nrgq";
  };
  mt7927DkmsSrc = builtins.fetchTarball {
    url = "https://github.com/jetm/mediatek-mt7927-dkms/archive/944dd50d890a91e1ae671bb978984d81acb3d438.tar.gz";
    sha256 = "193z8qqdg3lhx712p212dj49gqjr1nfpdvps80cwy8pksz3hr2cf";
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