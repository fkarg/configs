{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Proton compatibility tools (the Steam module also installs steam-run).
    protonup-qt
    mangohud
    goverlay
  ];

  # Modern Steam defaults based on the current NixOS Steam module.
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      # Keep Steam's older fontconfig away from incompatible shared caches.
      # https://issues.chromium.org/issues/565475896
      extraProfile = ''
        export XDG_CACHE_HOME="$HOME/.cache/steam-runtime"
      '';
    };
    protontricks.enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
    extraPackages = with pkgs; [
      gamescope
      mangohud
    ];
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode = {
    enable = true;
    enableRenice = true;
  };

  hardware.steam-hardware.enable = true;
}
