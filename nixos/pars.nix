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

        # global python
        pkgs.python311Packages.ipython
        pkgs.python311Packages.pygments
        pkgs.python311Packages.virtualenv
        pkgs.python311
        pkgs.poetry
        pkgs.pdm
        pkgs.ansible

        # rust
        pkgs.gcc12
        pkgs.rustup

        # haskell
        pkgs.ghc
        pkgs.cabal-install

        # tex
        pkgs.texlive.combined.scheme-full

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
  services.logind.extraConfig = "RuntimeDirectorySize=4G";
}
