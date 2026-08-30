{ config, lib, pkgs, ... }:

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

  # Native Hyprland sessions do not activate graphical-session.target on their
  # own. xdg-desktop-portal requires it, so expose the compositor lifecycle to
  # systemd without adopting a full session manager such as UWSM.
  systemd.user.targets.hyprland-session = {
    description = "Hyprland session";
    bindsTo = [ "graphical-session.target" ];
    wants = [ "graphical-session-pre.target" ];
    after = [ "graphical-session-pre.target" ];
    unitConfig.PropagatesStopTo = [ "graphical-session.target" ];
  };

  # pam_gnome_keyring (security.pam.services.<dm>.enableGnomeKeyring) starts
  # `gnome-keyring-daemon --login` at login and unlocks the login keyring, but
  # that daemon only sleeps until a second `--start` invocation hands it over to
  # the session; unconnected it gives up after a few minutes and exits. GNOME
  # does the handover from /etc/xdg/autostart, which Hyprland never runs — so
  # the unlocked daemon dies and whatever asks for a secret later D-Bus-activates
  # a fresh, locked one that prompts for the password.
  systemd.user.services.gnome-keyring-secrets =
    lib.mkIf config.services.gnome.gnome-keyring.enable {
      description = "Hand the PAM-unlocked keyring daemon to the session";
      wantedBy = [ "hyprland-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.security.wrapperDir}/gnome-keyring-daemon --start --components=secrets";
      };
    };

  # dpms is a Lua expression now: under a Lua config `hyprctl dispatch dpms on`
  # no longer parses and the screen simply never blanks or never comes back.
  # The `action` key is mandatory — hl.dsp.dpms("on") (a bare string) leaves
  # action nil and turns the display OFF. On jolly that is not recoverable
  # without a reboot: the monitor is also the USB KVM hub, so after ~90s without
  # a DP signal it auto-switches input and takes the keyboard with it.
  environment.etc."xdg/hypr/hypridle.conf".text = ''
    general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
    }

    # No idle auto-lock: current consumers are home towers. Locking stays
    # available manually (Super+A / Super+Shift+L) and on suspend via
    # before_sleep_cmd.
    listener {
        timeout = 1200
        on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'
        on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
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
