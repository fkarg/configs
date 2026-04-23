{ config, pkgs, ... }:

{
  # Root password for emergency mode
  users.users.root.initialPassword = "root";

  # Use LTS kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # automatically run `nix-store --optimize`
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # enable networkmanager
  networking.networkmanager.enable = true;
  networking.useDHCP = false;

  # Zswap configuration
  boot.kernelParams = [ "zswap.enabled=1" "zswap.compressor=lz4" "zswap.max_pool_percent=25" ];

  # Time zone and locale
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "neo";
  };

  services.xserver.xkb = {
    layout = "de";
    variant = "neo";
    options = "lv3:ralt_switch_multikey,compose:ralt";
  };

  # Sound
  services.pulseaudio.enable = true;
  services.pulseaudio.package = pkgs.pulseaudioFull;
  services.pipewire.enable = false;

  # Enable CUPS to print documents
  # services.printing.enable = true;

  # SSH
  services.openssh.enable = true;
  services.openssh.startWhenNeeded = true;

  programs.ssh = {
    startAgent = true;
    forwardX11 = true;
  };

  services.upower.enable = true;

  networking.networkmanager.appendNameservers = [
    "208.67.220.220"
    "208.67.222.222"
    "8.8.8.8"
  ];

  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    channel = "https://nixos.org/channels/nixpkgs-unstable";
  };
}