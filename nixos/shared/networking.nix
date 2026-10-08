{ pkgs, ... }:

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

  # Captive portals: while NM reports PORTAL/LIMITED, also route all lookups
  # to the default-route link's own DNS (resolved queries tied scopes in
  # parallel), so the portal's DNS answers; drop that again once FULL.
  # NM's check resolves per-link, so it detects portals despite the global ~.
  # Without a check URI NM never leaves an assumed FULL.
  networking.networkmanager.settings.connectivity.uri =
    "http://nmcheck.gnome.org/check_network_status.txt";
  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeShellScript "captive-portal-dns" ''
        [ "$2" = connectivity-change ] || exit 0
        PATH=${pkgs.iproute2}/bin:${pkgs.gawk}/bin:${pkgs.gnused}/bin:${pkgs.systemd}/bin
        dev=$(ip -o route show default | awk '{for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit }}')
        [ -n "$dev" ] || exit 0
        domains=$(resolvectl domain "$dev" | sed 's/^[^:]*: *//')
        case "$CONNECTIVITY_STATE" in
          PORTAL|LIMITED)
            case " $domains " in *" ~. "*) exit 0 ;; esac
            resolvectl domain "$dev" $domains '~.'
            ;;
          FULL)
            case " $domains " in *" ~. "*) ;; *) exit 0 ;; esac
            rest=$(echo "$domains" | awk '{for (i = 1; i <= NF; i++) if ($i != "~.") printf "%s ", $i}')
            resolvectl domain "$dev" ''${rest:-""}
            ;;
          *) exit 0 ;;
        esac
        resolvectl flush-caches
      '';
    }
  ];

  # tailscaled; the operator flag lets the tray/GUI clients run unprivileged
  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--operator=pars" ];
  };
}