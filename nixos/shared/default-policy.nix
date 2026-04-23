{ ... }:

{
  # Shared default policy entry point.
  imports = [
    ./policy/kernel.nix
    ./policy/pulseaudio.nix
    ./policy/auto-upgrade.nix
  ];
}