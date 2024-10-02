# List all the programs here that I tend to have installed everywhere globally
{ config, pkgs, ...}: with pkgs;

{
  environment.systemPackages = with pkgs; [
      # 'basic os functionality'
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
      xorg.xkill
      xorg.xinit
      inetutils
      gparted
      poppler_utils # pdfunite etc
      lm_sensors
      tree

      # misc productivity
      neovim
      vim  # vimdiff
      ripgrep
      ripgrep-all
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
      pulseaudioFull
      gnumake
      docker-compose
      openvpn
      shutter

      # python is in user: `pars.nix`
      # poetry
      # pdm
      # python311Packages.virtualenv
      # python311Packages.python

      # global for generating correct xdg-open/mime bindings
      # located at /run/current-system/sw/share/applications/

      # 'office'
      libreoffice-fresh
      gimp
      pstoedit
      inkscape
      dolphin

      # browser
      chromium
      firefox
      # tor-browser-bundle-bin

      # messenger
      tdesktop
      slack
      thunderbird
      signal-desktop

      # viewing pdfs
      evince
      pdfpc

      # for building i3status-rs
      pkg-config
      dbus.dev
      # for building in general
      binutils-unwrapped
      # gui open zip archives
      gnome3.file-roller
      # audio
      pavucontrol
      # 'better' terminal
      kitty
      alacritty
      tmux
      # composer for transparent terminal
      xcompmgr
      # extended uname
      neofetch
      # progress bar for cp/mv
      progress
      watch
      # for scientific research
      zotero

      # games
      steam

      # other / util
      subsurface # diving records
      networkmanagerapplet
      intel-gpu-tools
      libva-utils

      # fin
      beancount
      fava
  ];
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.pulseaudio = true;

  # fonts.
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    # mplus-outline-fonts
    dina-font
    proggyfonts
    font-awesome_4
  ];
}
