{ lib, pkgs, ... }:

{
  # Shared baseline for Hyprland/Wayland hosts.
  # This is intentionally not imported globally; non-Wayland machines can keep
  # a different audio or desktop stack.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  programs.hyprlock.enable = true;

  services.pipewire = {
    enable = lib.mkForce true;
    alsa.enable = true;
    alsa.support32Bit = true;
    # Keep PulseAudio protocol compatibility without running the old daemon.
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # Disable the old PulseAudio daemon on Wayland hosts using this baseline.
  services.pulseaudio.enable = lib.mkForce false;

  security.polkit.enable = true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  environment.systemPackages = with pkgs; [
    # launcher, notifications, and bar
    fuzzel
    mako
    waybar

    # Hyprland ecosystem tools
    hypridle
    hyprpaper
    hyprpicker
    hyprpolkitagent

    # screenshots and clipboard
    grim
    slurp
    wl-clipboard
    cliphist

    # session controls
    brightnessctl
    playerctl
  ];
}