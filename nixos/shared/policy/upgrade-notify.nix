{ config, lib, pkgs, ... }:

# Surface a failed system.autoUpgrade run instead of letting it fail silently.
#
# The failure mode this exists for: nixos-upgrade.service builds with
# operation = "boot", so a broken build stages nothing and the machine just
# keeps booting the last good generation. Nothing in the desktop changes, so a
# build can stay broken for weeks — an out-of-tree kernel module that stopped
# compiling wedged jolly's upgrades from 2026-08-05 to 2026-08-24 unnoticed.
#
# Two channels, because neither alone is sufficient:
#   * A desktop toast, for when the timer fires during a live session.
#   * A login check (dotconfig/fish/conf.d/nixos_upgrade_status.fish), because
#     mako does not persist notifications and the timer is Persistent=true —
#     a catch-up run right after boot can fire before the session is up.
let
  cfg = config.system.autoUpgrade;
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.nixos-upgrade-notify = {
      description = "Notify the desktop session that a NixOS upgrade failed";
      serviceConfig = {
        Type = "oneshot";
        User = "pars";
        # notify-send needs the user session bus; a system unit has no
        # DBUS_SESSION_BUS_ADDRESS of its own.
        Environment = "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${toString config.users.users.pars.uid}/bus";
      };
      # Best-effort: if no graphical session owns the bus, notify-send exits
      # non-zero. That is the expected headless case, not an error worth
      # surfacing — the fish login check is the backstop. Do not let it mark
      # the unit failed and generate a second layer of noise.
      script = ''
        ${pkgs.libnotify}/bin/notify-send \
          --urgency=critical \
          --app-name=nixos-upgrade \
          "NixOS upgrade failed on ${config.networking.hostName}" \
          "No new generation was staged. journalctl -u nixos-upgrade -e" || true
      '';
    };

    systemd.services.nixos-upgrade.onFailure = [ "nixos-upgrade-notify.service" ];
  };
}
