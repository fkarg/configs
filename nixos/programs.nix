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
      poppler_utils # pdfunite etc

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
      pulseaudioFull

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
    mplus-outline-fonts
    dina-font
    proggyfonts
    font-awesome_4
  ];
}
