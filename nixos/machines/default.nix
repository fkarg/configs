{ ... }:

{
  # Compatibility wrapper for the historic shared-machine import path.
  #
  # Active machines may continue importing this file while shared concerns are
  # gradually split into smaller modules.
  imports = [
    ../shared/base-system.nix
    ../shared/networking.nix
    ../shared/default-policy.nix
  ];
}