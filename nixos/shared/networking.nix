{ ... }:

{
  # enable networkmanager
  networking.networkmanager.enable = true;
  networking.useDHCP = false;

  # Device-wide DNS: Quad9 for general lookups, never the ISP's/network's
  # resolver. resolved routes each name to the best-matching domain, so the
  # global "~." only claims what nothing more specific does: the connected
  # network's DHCP search domain (e.g. fritz.box) still resolves via its own
  # router, and tailscaled registers MagicDNS on tailscale0.
  networking.nameservers = [
    "9.9.9.9#dns.quad9.net"
    "149.112.112.112#dns.quad9.net"
    "2620:fe::fe#dns.quad9.net"
    "2620:fe::9#dns.quad9.net"
  ];
  networking.networkmanager.dns = "systemd-resolved";
  services.resolved = {
    enable = true;
    settings.Resolve = {
      Domains = [ "~." ];
      # Opportunistic, not strict: captive portals often block port 853
      # before login.
      DNSOverTLS = "opportunistic";
    };
  };

  # tailscaled; the operator flag lets the tray/GUI clients run unprivileged
  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--operator=pars" ];
  };
}