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
  users.users.pars = {
    isNormalUser = true;
    uid = 1000;
    shell = "${pkgs.fish}/bin/fish";
    extraGroups = [ "wheel" "networkmanager" "video" "lxd" "docker"];
    home = "/home/pars";
    # initialHashedPassword = "$6$zJ3UEKSmFpLzlEF$OWR9kYnCeNF3TH5xlvaXGVTPzNvwOyK6lLFMr9I3F1Z1octemDpUqfRncNcOJQDepHzRTX2a2Aiz1eQ.MssSw/";
  };

  environment.variables = {
    EDITOR = "nvim";
    BROWSER = "chromium";
    PAGER = "less -R";
  };



}
