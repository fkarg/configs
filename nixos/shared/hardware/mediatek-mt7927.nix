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
in
{
  imports = [ mt7927.nixosModules.default ];

  hardware.mediatek-mt7927 = {
    enable = true;
    enableWifi = true;
    enableBluetooth = true;
    disableAspm = true;
  };
}