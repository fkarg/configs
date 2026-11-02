{ config, lib, pkgs, ... }:

let
  # Same compositor as the plain "Hyprland" entry; hyprland.lua reads
  # HYPRLAND_SHELL and starts DankMaterialShell instead of waybar, mako, the
  # polkit agent, the tray applets and cliphist.
  #
  # mako is masked for the session: anything notifying before DMS has claimed
  # org.freedesktop.Notifications would otherwise D-Bus-activate mako.service,
  # which then holds the name for good and DMS's notification server never
  # registers. --runtime lives in $XDG_RUNTIME_DIR, so it is gone once the user
  # manager stops; the plain session starts mako directly, not via D-Bus.
  startHyprlandDms = pkgs.writeShellScript "start-hyprland-dms" ''
    export HYPRLAND_SHELL=dms
    systemctl --user mask --runtime mako.service
    exec ${config.programs.hyprland.package}/bin/start-hyprland
  '';

  dmsSession =
    (pkgs.writeTextDir "share/wayland-sessions/hyprland-dms.desktop" ''
      [Desktop Entry]
      Name=Hyprland (Dank)
      Comment=Hyprland with DankMaterialShell
      Exec=${startHyprlandDms}
      Type=Application
      DesktopNames=Hyprland
    '').overrideAttrs (_: { passthru.providedSessions = [ "hyprland-dms" ]; });
in
{
  # DankMaterialShell as an opt-in shell, picked per login in GDM's session
  # chooser. dms.service would otherwise hang off graphical-session.target and
  # start in every session (plain Hyprland, and GNOME on jolly), fighting mako
  # over org.freedesktop.Notifications. Bind it to its own target instead,
  # which only the "Hyprland (Dank)" session starts.
  programs.dux-shell = {
    enable = true;
    systemd.target = "dms-session.target";
  };

  # The packaged unit only restarts on failure, but the shell has been seen
  # vanishing with a clean exit (the UI dies, systemd SIGTERMs the unit when
  # the org.freedesktop.Notifications bus name drops, and `dms run` exits 0).
  # Stopping the unit or target still stops it for good.
  systemd.user.services.dms.serviceConfig.Restart = "always";

  systemd.user.targets.dms-session = {
    description = "DankMaterialShell session";
    requires = [ "hyprland-session.target" ];
    after = [ "hyprland-session.target" ];
    partOf = [ "hyprland-session.target" ];
  };

  services.displayManager.sessionPackages = [ dmsSession ];
}
