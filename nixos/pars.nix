# # still missing parts:
# git config for fkarg
# - mail
# - name
# - editor
# - always pull with rebase
#
# .config settings
# - nvim/init.vim
#     nix highlighting
# - i3/config
# - fish/config.fish
# - htop/htoprc
# - broot/**
#
# other configs
# - i3status-rs
# - 'b'
# - status.sh
# - multiscreen.sh
# - upStat.sh
# - thunderbird signatures
# - background picture

{ config, pkgs, ... }: with pkgs;
{

  programs.fish.enable = true;
  programs.neovim.enable = true;
  programs.evince.enable = true;
  programs.chromium = {
    enable = true;
    extraOpts = {}; # don't enable any 'policy'-management
  };

  users.users.pars = {
    isNormalUser = true;
    uid = 1000;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "pulse"
      "lxd"
      "docker"
      "adbusers"
    ];
    home = "/home/pars";
    packages = [
        # util
        pkgs.fish
        # pkgs.etcher
        pkgs.todo-txt-cli
        # pkgs.obsidian

        # browser
        pkgs.chromium
        pkgs.firefox
        # pkgs.tor-browser-bundle-bin

        # messaging
        pkgs.thunderbird
        pkgs.signal-desktop
        pkgs.tdesktop
        pkgs.teams
        pkgs.mumble

        # viewing pdfs
        pkgs.evince
        pkgs.pdfpc

        # global python
        pkgs.python39Packages.ipython
        pkgs.python3
        pkgs.ansible

        # rust
        pkgs.gcc
        pkgs.rustup

        # haskell
        pkgs.ghc
        pkgs.cabal-install

        # tex
        pkgs.texlive.combined.scheme-full

        # image editing
        pkgs.inkscape
        pkgs.pstoedit
        pkgs.gimp

        # office
        pkgs.libreoffice-fresh

        # fun
        pkgs.cowsay
        pkgs.fortune
        pkgs.sl
        pkgs.doge

        # nixpkgs.
        # nixpkgs.
    ];
  };

  environment.variables = {
    EDITOR = "nvim";
    BROWSER = "chromium";
    PAGER = "less -R";
    TZ = "Europe/Berlin";
    LD_LIBRARY_PATH = "${stdenv.cc.cc.lib}/lib/libstdc++.so.6";
    FZF_DEFAULT_COMMAND = "rg --files --no-ignore --hidden --follow --glob '!.git/*'";
  };

  # Enable cron service
  services.cron = {
    enable = true;
    systemCronJobs = [
      "0 * * * *      pars  /home/pars/passive_update.sh"
      "0 * * * *      pars  nix-channel --update"
    ];
  };
  services.logind.extraConfig = "RuntimeDirectorySize=4G";

  # networking.nameservers = [
  networking.networkmanager.appendNameservers = [
    "208.67.220.220"
    "208.67.222.222"
    "8.8.8.8"
  ];
}
