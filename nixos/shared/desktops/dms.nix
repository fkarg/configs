{ config, lib, pkgs, ... }:

let
  # Same compositor as the plain "Hyprland" entry; hyprland.lua reads
  # HYPRLAND_SHELL and starts DankMaterialShell instead of waybar, mako, the
  # polkit agent, the tray applets and cliphist.
  startHyprlandDms = pkgs.writeShellScript "start-hyprland-dms" ''
    export HYPRLAND_SHELL=dms
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
  programs.dms-shell = {
    enable = true;
    systemd.target = "dms-session.target";
  };

  systemd.user.targets.dms-session = {
    description = "DankMaterialShell session";
    requires = [ "hyprland-session.target" ];
    after = [ "hyprland-session.target" ];
    partOf = [ "hyprland-session.target" ];
  };

  services.displayManager.sessionPackages = [ dmsSession ];
}
