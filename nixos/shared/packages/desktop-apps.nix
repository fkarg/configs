{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # media and document tools
    vlc
    klavaro
    pdftk
    ghostscript

    # office and content creation
    # libreoffice-fresh
    # gimp

    # browsers and desktop-entry providers
    # Keep browsers here when they should be selectable as system defaults.
    chromium
    firefox

    # communication
    telegram-desktop
    slack
    thunderbird
    signal-desktop
    protonmail-desktop
    proton-vpn

    # reading and presentations
    evince
    pdfpc

    # desktop applications
    vscode.fhs
    zotero
    subsurface

    # misc heavy applications
    steam-run
    proton-pass
    ollama
  ];
}