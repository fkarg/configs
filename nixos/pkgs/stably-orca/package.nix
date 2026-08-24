# Stably Orca — an Electron IDE for orchestrating coding agents in parallel git
# worktrees. Not in nixpkgs, and note that `pkgs.orca` is the *GNOME screen
# reader*, which GNOME pulls into this host's environment already. Upstream
# names its own binary `orca-ide` for exactly that reason, so the two coexist.
#
# Built from upstream's .deb rather than their AppImage: no squashfs+FUSE
# runtime layer in the closure, real desktop entry and icons, and a wrapper we
# control. It also sidesteps the self-updater — electron-updater's in-place
# rewrite path is AppImage-only, so a deb-derived install can't mutate itself
# in the read-only store.
#
# There is no checked-in version pin: the release to build is read from
# upstream's feed at evaluation time, so `nixos-rebuild boot` always stages
# whatever is current with nothing to bump by hand. See the note at `feed`
# below for what that trades away.
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
  # electron-builder publishes this next to every release: a ~700 byte manifest
  # at a stable URL, listing the current version and a per-artifact sha512. That
  # sha512 is base64 of the raw digest, which is byte-for-byte Nix's SRI
  # encoding, so it can be handed to fetchurl verbatim.
  #
  # Only this manifest is fetched impurely (hashless, so re-checked per
  # tarball-ttl, an hour by default). The 160MB .deb underneath stays an
  # ordinary fixed-output derivation with a real hash, so it is cached and
  # substitutable exactly like any other fetchurl.
  #
  # The cost of doing it this way: evaluation now depends on GitHub being
  # reachable, so an outage fails *every* nixos-rebuild on this host, not just
  # this package. And re-evaluating the same git state later can produce a
  # different Orca — deliberate here, but it is also why flakes reject this
  # (pure evaluation forbids a hashless fetch).
  feed = lib.splitString "\n" (
    builtins.readFile (
      builtins.fetchurl "https://github.com/stablyai/orca/releases/latest/download/latest-linux.yml"
    )
  );

  version =
    let
      line = lib.findFirst (lib.hasPrefix "version: ") null feed;
    in
    if line == null then
      throw "stably-orca: no version field in upstream release feed"
    else
      lib.removePrefix "version: " line;

  debFile = "orca-ide_${version}_amd64.deb";

  # In the files list each artifact is a `- url: <name>` line immediately
  # followed by its `sha512:`. Match the deb's entry specifically — the
  # top-level sha512 key at the end of the manifest belongs to the AppImage.
  debHash =
    let
      idx = lib.lists.findFirstIndex (lib.hasSuffix "url: ${debFile}") null feed;
    in
    if idx == null then
      throw "stably-orca: ${debFile} not listed in upstream release feed"
    else
      "sha512-" + lib.removePrefix "sha512: " (lib.trim (lib.elemAt feed (idx + 1)));
in
stdenv.mkDerivation {
  pname = "stably-orca";
  inherit version;

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/${debFile}";
    hash = debHash;
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
}
