let
  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/55bfb4d7437bd4e09ab7cba58a43bd68eb310044.tar.gz";
    sha256 = "02sljlk6abwqsx32nhjmfbm7hki7nvcsg442ldp0yx9f5qz0c5lc";
  }) { };
in
pkgs.mkShell {
  packages = with pkgs; [
    qemu_kvm cloud-utils openssh curl coreutils util-linux gh
    python3Packages.pyyaml shellcheck
  ];
}
