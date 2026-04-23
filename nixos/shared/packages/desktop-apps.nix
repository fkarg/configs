{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # desktop utilities
    redshift
    feh
    vlc
    screen-message
    klavaro
    baobab
    pdftk
    ghostscript
    scrot
    shutter

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

    # desktop applications and integration helpers
    vscode.fhs
    file-roller
    pavucontrol
    zotero
    subsurface
    networkmanagerapplet
    intel-gpu-tools
    libva-utils

    # misc heavy applications
    steam-run
    proton-pass
    ollama
  ];
}