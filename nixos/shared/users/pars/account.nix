{ pkgs, ... }:

{
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
  };
}