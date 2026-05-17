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
