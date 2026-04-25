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

  # PipeWire expects realtime scheduling support for reliable desktop audio.
  security.rtkit.enable = true;
  security.polkit.enable = true;

  environment.etc."xdg/hypr/hypridle.conf".text = ''
    general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
    }

    listener {
        timeout = 900
        on-timeout = loginctl lock-session
    }

    listener {
        timeout = 1200
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
    }
  '';

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
  };

  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/desktop/interface" = {
        cursor-theme = "Bibata-Modern-Classic";
        cursor-size = lib.gvariant.mkInt32 24;
      };
    }
  ];

  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    NIXOS_OZONE_WL = "1";
  };

  environment.systemPackages = with pkgs; [
    # launcher, notifications, and bar
    bibata-cursors
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