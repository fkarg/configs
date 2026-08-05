{ lib, ... }:

{
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.pulseaudio = true;

  # Temporary nixos-unstable workarounds for currently broken package/build
  # paths pulled into this desktop configuration.
  nixpkgs.overlays = [
    (final: prev: {
      vscode = prev.vscode.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.jq.bin ];
      });

      # glaze 7.9.1 -> 8.0.0 (nixpkgs#548864) broke hyprland 0.56.1: its
      # `find_package(glaze 7...<8)` rejects glaze 8, and the FetchContent
      # fallback wants to git-clone glaze v7.2.0 inside the sandbox.
      # Upstream fix (nixpkgs#549253) is merged to master but has not reached
      # the nixos-unstable channel yet; drop this once it has.
      hyprland = prev.hyprland.overrideAttrs (old: {
        postPatch = ''
          substituteInPlace CMakeLists.txt start/CMakeLists.txt hyprpm/CMakeLists.txt \
            --replace-fail "glaze 7...<8" "glaze"
        '' + (old.postPatch or "");
      });

      makeModulesClosure =
        {
          kernel,
          firmware,
          rootModules,
          allowMissing ? false,
          extraFirmwarePaths ? [ ],
        }:
        final.stdenvNoCC.mkDerivation {
          name = kernel.name + "-shrunk";
          builder = final.writeShellScript "modules-closure-builder" ''
            export PATH=${lib.makeBinPath [
              final.coreutils
              final.gnugrep
              final.gnused
              final.kmod
              final.nukeReferences
            ]}:$PATH
            exec ${final.bash}/bin/bash ${prev.path}/pkgs/build-support/kernel/modules-closure.sh
          '';
          inherit
            kernel
            firmware
            rootModules
            allowMissing
            extraFirmwarePaths
            ;
          allowedReferences = [ "out" ];
        };
    })
  ];
}
