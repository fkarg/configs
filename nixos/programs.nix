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
      poppler-utils # pdfunite etc
      lm_sensors
      tree
      usbutils

      # network debugging
      dig
      nmap

      # misc productivity
      neovim
      vim  # vimdiff
      ripgrep
      ripgrep-all
      broot
      direnv
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
      zellij
      zoxide

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
      # pstoedit
      # inkscape

      # browser
      chromium
      firefox
      # tor-browser-bundle-bin

      # messenger
      telegram-desktop
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
      file-roller
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
      steam-run

      # other / util
      subsurface # diving records
      networkmanagerapplet
      intel-gpu-tools
      libva-utils
      wireguard-tools
      nettools

      # fin
      beancount
      fava

      # signal
      clang
      libclang
      cmake
      gnumake
      protobuf
  ];
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.pulseaudio = true;

  programs.ausweisapp = {
    openFirewall = true;
    enable = true;
  };

  # fonts.
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    # mplus-outline-fonts
    dina-font
    proggyfonts
    font-awesome_4
  ];
}
