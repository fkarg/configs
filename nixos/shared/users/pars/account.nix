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
      "i2c"  # ddcutil access for the Hyprland Ctrl+Shift+F12 KVM input switch
    ];
    home = "/home/pars";
  };
}