{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # basic os functionality
    wget
    git
    git-lfs
    eza
    curl
    openssl
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
    parted
    poppler-utils
    lm_sensors
    tree
    usbutils
    jq
    lsof
    bat
    coreutils
    cowsay
    fortune
    gh
    glow
    yq
    socat
    zellij
    zoxide
    fastfetch
    progress
    watch
    nettools
    wireguard-tools

    # media
    ffmpeg
    yt-dlp

    # network debugging
    dig
    ldns
    mosh
    nmap

    # terminal and editor baseline
    neovim
    vim
    ripgrep
    ripgrep-all
    broot
    fzf
    lf
    direnv
    kitty
    alacritty
    tmux
    nix-output-monitor
  ];
}
