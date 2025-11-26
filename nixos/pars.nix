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
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    zlib # e.g. for numpy
    libgcc # e.g. for sqlalchemy
    # that's where the shared libs go, you can find which one you need using
    # nix-locate --top-level libstdc++.so.6  (replace this with your lib)
    # ^ this requires `nix-index` pkg
  ];

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
      "lp"
    ];
    home = "/home/pars";
    packages = [
        # util
        pkgs.fish
        pkgs.todo-txt-cli

        # dev
        pkgs.postgresql

        # global python
        pkgs.python313Packages.ipython
        pkgs.python313Packages.pygments
        pkgs.python313Packages.virtualenv
        pkgs.python313Packages.uv
        pkgs.python313
        pkgs.poetry
        pkgs.pdm
        pkgs.ansible

        # rust
        pkgs.gcc
        pkgs.rustup

        # haskell
        pkgs.ghc
        pkgs.cabal-install

        # JS
        nodejs
        pnpm

        # tex
        # pkgs.texlive.combined.scheme-full
        pkgs.typst

        # fun
        pkgs.cowsay
        pkgs.fortune
        pkgs.sl
        pkgs.doge

        pkgs.xdg-user-dirs
    ];
  };

  environment.variables = {
    EDITOR = "nvim";
    BROWSER = "chromium";
    PAGER = "less -R";
    TZ = "Europe/Berlin";
    # LD_LIBRARY_PATH = "$LD_LIBRARY_PATH:${pkgs.gcc12.cc.lib}/lib64/:${stdenv.cc.cc.lib}/lib/";
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
  # services.logind.extraConfig = "RuntimeDirectorySize=4G";
}
