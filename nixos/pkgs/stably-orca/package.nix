# Stably Orca — an Electron IDE for orchestrating coding agents in parallel git
# worktrees. Not in nixpkgs, and note that `pkgs.orca` is the *GNOME screen
# reader*, which GNOME pulls into this host's environment already. Upstream
# names its own binary `orca-ide` for exactly that reason, so the two coexist.
#
# Built from upstream's .deb rather than their AppImage: no squashfs+FUSE
# runtime layer in the closure, real desktop entry and icons, and a wrapper we
# control. It also sidesteps the self-updater — electron-updater's in-place
# rewrite path is AppImage-only, so a deb-derived install can't mutate itself
# in the read-only store. Version bumps come from ../../shared/programs/
# stably-orca.nix driving ./update.sh instead.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  addDriverRunpath,
  libglvnd,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libgbm,
  libnotify,
  libxkbcommon,
  nspr,
  nss,
  pango,
  systemdLibs,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  git,
  xclip,
  xdotool,
  xvfb-run,
}:

let
  source = lib.importJSON ./source.json;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "stably-orca";
  version = source.version;

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${finalAttrs.version}/orca-ide_${finalAttrs.version}_amd64.deb";
    hash = source.hash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libgbm
    libxkbcommon
    nspr
    nss
    pango
    systemdLibs
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
  ];

  # Everything here is dlopen'd rather than declared in DT_NEEDED, so autoPatchelf
  # cannot infer any of it:
  #   * the app dir itself — libffmpeg.so and the bundled GL/Vulkan stubs sit
  #     next to the executable rather than in a store lib dir;
  #   * libnotify, reached through Electron's notification API;
  #   * libglvnd, which is what actually provides libEGL.so.1. /run/opengl-driver
  #     ships only vendor libs (libEGL_nvidia.so), never the glvnd dispatch lib,
  #     so without this Chromium fails EGL init and falls back to software;
  #   * the driver link, so glvnd can then resolve the vendor library behind it.
  appendRunpaths = [
    "${placeholder "out"}/share/orca-ide"
    "${lib.getLib libnotify}/lib"
    "${lib.getLib libglvnd}/lib"
    "${addDriverRunpath.driverLink}/lib"
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/orca-ide $out/share/applications
    cp -r opt/Orca/. $out/share/orca-ide/
    cp -r usr/share/icons $out/share/

    # Chromium's setuid sandbox helper cannot be setuid from the read-only
    # store, and Electron aborts on a present-but-not-setuid helper rather than
    # falling back. Dropping it selects the user-namespace sandbox, which NixOS
    # enables by default. Same treatment nixpkgs gives trilium-desktop and obs.
    rm $out/share/orca-ide/chrome-sandbox

    # Runtime PATH deps, taken from the deb's own Depends/Recommends: the
    # agent-automation paths shell out to xdotool and xclip, `orca-ide serve`
    # wants xvfb-run on a host with no display, and the whole premise of the
    # app is driving git worktrees.
    # XDG_DATA_DIRS carries the driver link's share/ so glvnd finds the EGL
    # vendor JSON and Vulkan its ICD manifest; a runpath alone is not enough,
    # those are looked up by data path. The Ozone flags are gated on
    # NIXOS_OZONE_WL (set by shared/desktops/hyprland-session.nix) so the same
    # wrapper still does the right thing under X11 or a bare TTY.
    makeWrapper $out/share/orca-ide/orca-ide $out/bin/orca-ide \
      --prefix PATH : ${
        lib.makeBinPath [
          git
          xclip
          xdotool
          xvfb-run
        ]
      } \
      --prefix XDG_DATA_DIRS : ${addDriverRunpath.driverLink}/share \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-wayland-ime=true}}"

    substitute usr/share/applications/orca-ide.desktop \
      $out/share/applications/orca-ide.desktop \
      --replace-fail /opt/Orca/orca-ide $out/bin/orca-ide

    runHook postInstall
  '';

  meta = {
    description = "Next-gen IDE for parallel agentic development";
    homepage = "https://github.com/stablyai/orca";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "orca-ide";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
