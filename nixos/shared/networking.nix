{ ... }:

{
  # enable networkmanager
  networking.networkmanager.enable = true;
  networking.useDHCP = false;

  networking.networkmanager.appendNameservers = [
    "208.67.220.220"
    "208.67.222.222"
    "8.8.8.8"
  ];
}