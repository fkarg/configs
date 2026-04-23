{ ... }:

{
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    channel = "https://nixos.org/channels/nixpkgs-unstable";
  };
}