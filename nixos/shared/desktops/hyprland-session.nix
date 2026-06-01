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
  services.hypridle.enable = lib.mkForce false;

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
      settings."org/gnome/mutter" = {
        dynamic-workspaces = false;
      };
      settings."org/gnome/desktop/wm/preferences" = {
        num-workspaces = lib.gvariant.mkInt32 10;
      };
    }
  ];

  environment.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  environment.systemPackages = with pkgs; [
    # launchers, notifications, and bar
    bibata-cursors
    fuzzel
    hyprlauncher
    mako
    rofi
    tofi
    waybar
    walker
    wofi
    bemenu
    nwg-drawer
    sherlock-launcher
    anyrun

    # status, sensors, and system monitors
    btop
    lm_sensors
    mission-center
    nvtopPackages.nvidia

    # Hyprland ecosystem tools
    hypridle
    hyprpaper
    hyprpicker
    hyprpolkitagent
    # hy3 plugin (column-based layout for clean N-way splits on ultrawide) is
    # intentionally NOT added: in the current channel the packaged hy3
    # (0.54.2.1) fails to compile against this hyprland (0.55.2). Re-enable
    # once nixpkgs catches up, then load it from hyprland.conf with
    #   plugin = /run/current-system/sw/lib/libhy3.so
    # and switch the layout via `general { layout = hy3; }`. When that lands,
    # reintroduce an N-way "equalize tiled windows" action (removed from
    # dotconfig/hypr/hypr-resize): hy3's columns make it reliable, whereas
    # dwindle's opaque split-tree collapses columns for 3+ windows.

    # screenshots and clipboard
    grim
    hyprshot
    slurp
    swappy
    wl-clipboard
    cliphist

    # file manager and session controls
    lf
    brightnessctl
    playerctl
  ];
}