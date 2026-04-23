{ pkgs, ... }:

{
  # Shared PulseAudio baseline. Hosts can override this while migrating.
  services.pulseaudio.enable = true;
  services.pulseaudio.package = pkgs.pulseaudioFull;
  services.pipewire.enable = false;
}