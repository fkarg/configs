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

  users.users.pars = {
    isNormalUser = true;
    uid = 1000;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "video" "lxd" "docker"];
    home = "/home/pars";
    packages = [
        pkgs.chromium
        pkgs.etcher
        pkgs.fish
        pkgs.teams
        pkgs.tdesktop
        pkgs.tor-browser-bundle-bin
        pkgs.thunderbird
        # nixpkgs.
        # nixpkgs.
    ];
  };

  environment.variables = {
    EDITOR = "nvim";
    BROWSER = "chromium";
    PAGER = "less -R";
    LD_LIBRARY_PATH = "${stdenv.cc.cc.lib}/lib/libstdc++.so.6";
  };


}
