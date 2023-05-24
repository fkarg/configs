# List all the programs here that I tend to have installed everywhere globally
{ config, pkgs, ...}: with pkgs;

{
  environment.systemPackages = with pkgs; [
      # 'basic os functionality'
      wget
      git
      exa
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
      # busybox

      # misc productivity
      neovim
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

      # global for generating correct xdg-open/mime bindings
      # located at /run/current-system/sw/share/applications/
      evince
      teams
      zoom-us
      tdesktop
      libreoffice-fresh
      chromium
      slack
      dolphin

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
      # Run github actions locally: https://github.com/nektos/act
      act
      # for academic stuff
      zotero

      # other
      subsurface # diving records
      # obsidian  # using deprecated electron version
      networkmanagerapplet
      intel-gpu-tools
      libva-utils
      beancount
      fava
      # poetry

  ];
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.pulseaudio = true;

  # fonts.
  fonts.fonts = with pkgs; [
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
