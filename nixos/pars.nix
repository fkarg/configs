# # put here:
# git config for fkarg
# - mail
# - name
# - editor
# - always pull
#
# user config for pars
# - groups
# - home directory
# - environment.variables = {
#     EDITOR = "vim";
#     BROWSER = "links";
#     PAGER = "less";
#   };
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

{ config, pkgs, ... }: with pkgs;
{
  users.users.pars = {
    isNormalUser = true;
    uid = 1000;
    shell = "${pkgs.fish}/bin/fish";
    extraGroups = [ "wheel" "networkmanager" "video"];
    home = "/home/pars";
  };
}
