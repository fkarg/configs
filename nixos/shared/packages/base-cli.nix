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

    # nix tooling. Documented here because the fish abbrs that drive these live
    # in dotconfig/fish/fish_variables, which fish rewrites wholesale on any
    # universal-variable change — comments there would not survive.
    #
    # nix-search (diamondburned) indexes the *channel this host actually tracks*
    # (--channel defaults to <nixpkgs>), so hits match what a rebuild would give,
    # and searching is offline + instant. The index is built on first use and
    # goes stale on nix-channel --update / `nrb`'s --upgrade; `nsi` re-indexes
    # (~15s). Binary is `nix-search`, which collides with nix-search-cli — only
    # one of the two can be installed.
    #
    # nix-search-tv covers what nix-search doesn't: NixOS and home-manager module
    # options. It has no interface of its own — `print` emits one entry per line
    # (nixpkgs + nixos + home-manager + nur by default on Linux) for fzf to
    # filter, and `preview {}` renders the highlighted one. That's the `nso` abbr.
    nix-search
    nix-search-tv

    # nom renders nix's build output as a live tree; `nrs`/`nrb` pipe through it
    # with fish's `&|` (stdout+stderr), since nix logs progress on stderr.
    nix-output-monitor
  ];
}
