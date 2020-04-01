# List all the programs here that I tend to have installed everywhere globally
{ config, pkgs, ...}: with pkgs;

{
  environment.systemPackages = with pkgs; [
      # 'basic os functionality'
      wget
      git
      curl
      fish
      htop
      iftop
      zip
      unzip
      screen
      xclip
      xorg.xkill
      xorg.xinit
      inetutils
      gparted
      # misc productivity
      neovim
      ripgrep
      broot
      redshift
      feh
      vlc
      jq
      lsof
      screen-message
      klavaro
      baobab
      pdftk
      ghostscript
      scrot
      tokei
      # todo\.txt-cli
      anki
      # wireshark
      # filezilla

      # for building i3status-rs
      pkg-config
      dbus.dev
      # for building in general
      binutils-unwrapped
      # gui open zip archives
      gnome3.file-roller
      # spellchecking
      aspell
      aspellDicts.de
      aspellDicts.en
      aspellDicts.en-science
      aspellDicts.en-computers
      # unstable.etcher
      # global python
      python37Packages.ipython
      python3
      # rust
      gcc
      rustup
      # haskell
      ghc
      cabal-install
      # E-mail program
      thunderbird
      # viewing pdfs
      evince
      pdfpc
      # browsers
      firefox
      chromium
      tor-browser-bundle-bin
      # audio
      pavucontrol
      # 'better' terminal
      kitty
      alacritty
      tmux
      # composer for transparent terminal
      xcompmgr
      # tex
      texlive.combined.scheme-full
      # image editing
      inkscape
      pstoedit
      # office
      libreoffice-fresh
      # fun
      cowsay
      fortune
      sl
      doge
      # messaging
      mumble
      tdesktop
      # skype
  ];
  nixpkgs.config.allowUnfree = true;

  # fonts.
  fonts.fonts = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts
    dina-font
    proggyfonts
    font-awesome_4
  ];
}
