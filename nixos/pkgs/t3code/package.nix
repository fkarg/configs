# T3 Code desktop app, packaged from upstream's Debian release artifact.
# The version and artifact hash come from the electron-builder release manifest,
# so a NixOS rebuild picks up the latest stable release without a manual bump.
# Like stably-orca, this makes evaluation depend on GitHub being reachable and
# the same config revision can resolve to a newer release on a later rebuild.
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
  libsecret,
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
  libXScrnSaver,
  libXtst,
  xdg-utils,
  version ? null,
}:

let
  # electron-builder publishes each release's version and per-artifact sha512
  # in this manifest. Its base64 digest is also Nix's SRI representation.
  feed = lib.splitString "\n" (
    builtins.readFile (
      builtins.fetchurl (
        if version == null then
          "https://github.com/pingdotgg/t3code/releases/latest/download/latest-linux.yml"
        else
          "https://github.com/pingdotgg/t3code/releases/download/v${version}/latest-linux.yml"
      )
    )
  );

  resolvedVersion =
    let
      line = lib.findFirst (lib.hasPrefix "version: ") null feed;
    in
    if version != null then version else if line == null then
      throw "t3code: no version field in upstream release feed"
    else
      lib.removePrefix "version: " line;

  debFile = "T3-Code-${resolvedVersion}-amd64.deb";

  debHash =
    let
      idx = lib.lists.findFirstIndex (lib.hasInfix "url: ${debFile}") null feed;
    in
    if idx == null then
      throw "t3code: ${debFile} not listed in upstream release feed"
    else
      "sha512-" + lib.removePrefix "sha512: " (lib.trim (lib.elemAt feed (idx + 1)));
in
stdenv.mkDerivation {
  pname = "t3code";
  version = resolvedVersion;

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${resolvedVersion}/${debFile}";
    hash = debHash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  # The release bundles Linux binaries for other libc/platform targets under
  # resources. Patch the Electron executable and its Linux node-pty addon only.
  dontAutoPatchelf = true;
  autoPatchelfIgnoreMissingDeps = [ "libffmpeg.so" ];
  postFixup = ''
    autoPatchelf \
      "$out/share/t3code/t3code" \
      "$out/share/t3code/resources/app.asar.unpacked/node_modules/node-pty/prebuilds/linux-x64/pty.node"
  '';

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
    libsecret
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
    libXScrnSaver
    libXtst
    stdenv.cc.cc.lib
  ];

  # Electron dlopens notification, secret-service, and GL libraries. The
  # packaged ffmpeg library also sits beside the executable.
  appendRunpaths = [
    "${placeholder "out"}/share/t3code"
    "${lib.getLib libnotify}/lib"
    "${lib.getLib libsecret}/lib"
    "${lib.getLib libglvnd}/lib"
    "${addDriverRunpath.driverLink}/lib"
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/t3code" "$out/share/applications" "$out/share/icons"
    cp -r "opt/T3 Code (Beta)/." "$out/share/t3code/"
    cp -r usr/share/icons/. "$out/share/icons/"

    # A setuid helper cannot work in the immutable store. Electron falls back
    # to its user-namespace sandbox, which NixOS enables by default.
    rm "$out/share/t3code/chrome-sandbox"

    makeWrapper "$out/share/t3code/t3code" "$out/bin/t3code-desktop" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-wayland-ime=true}}"

    substitute usr/share/applications/t3code.desktop \
      "$out/share/applications/t3code.desktop" \
      --replace-fail 'Exec="/opt/T3 Code (Beta)/t3code"' "Exec=$out/bin/t3code-desktop"

    runHook postInstall
  '';

  meta = {
    description = "Desktop app for coding agents";
    homepage = "https://t3.codes";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "t3code-desktop";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
