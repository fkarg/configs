{ pkgs, ... }:

{
  # Root password for emergency mode
  users.users.root.initialPassword = "root";

  # Use LTS kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Zswap configuration
  boot.kernelParams = [ "zswap.enabled=1" "zswap.compressor=lz4" "zswap.max_pool_percent=25" ];

  # Sound
  services.pulseaudio.enable = true;
  services.pulseaudio.package = pkgs.pulseaudioFull;
  services.pipewire.enable = false;

  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    channel = "https://nixos.org/channels/nixpkgs-unstable";
  };
}