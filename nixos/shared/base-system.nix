{ ... }:

{
  # automatically run `nix-store --optimize`
  nix.settings.auto-optimise-store = true;
  # fsync store paths before registering them as valid: without this, a
  # power loss mid-build/download leaves zero-length files that Nix still
  # considers valid (bit jolly on 2026-07-27, corrupted gen 44's mesa +
  # graphics-driver.conf and broke every compositor)
  nix.settings.fsync-store-paths = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 90d";
  };

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
}