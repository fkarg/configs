{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # basic os functionality
    wget
    git
    git-lfs
    eza
    curl
    fish
    htop
    btop
    iftop
    zip
    unzip
    gnutar
    screen
    xclip
    inetutils
    gparted
    poppler-utils
    lm_sensors
    tree
    usbutils
    jq
    lsof
    bat
    coreutils
    gh
    yq
    socat
    zellij
    zoxide
    fastfetch
    progress
    watch
    nettools
    wireguard-tools

    # network debugging
    dig
    nmap

    # terminal and editor baseline
    neovim
    vim
    ripgrep
    ripgrep-all
    broot
    direnv
    kitty
    alacritty
    tmux
    nix-output-monitor
  ];
}