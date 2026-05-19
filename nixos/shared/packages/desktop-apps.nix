{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # media and document tools
    vlc
    klavaro
    pdftk

    # office and content creation
    libreoffice-fresh
    languagetool
    tinymist
    # gimp

    # browsers and desktop-entry providers
    # Keep browsers here when they should be selectable as system defaults.
    (chromium.override {
      commandLineArgs = "--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true";
    })
    firefox
    (google-chrome.override {
      commandLineArgs = "--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true";
    })
    tor-browser

    # communication
    discord
    telegram-desktop
    teams-for-linux
    thunderbird
    signal-desktop
    karere  # gtk4 client for whatsapp
    protonmail-desktop
    proton-vpn

    # reading and presentations
    evince
    pdfpc

    # desktop applications
    kdePackages.dolphin
    kdePackages.kio-extras
    obsidian
    vscode.fhs
    zotero
    subsurface

    # misc heavy applications
    proton-pass
    ollama
    lmstudio
    ytmdesktop
  ];
}
