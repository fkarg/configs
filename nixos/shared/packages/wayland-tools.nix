{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Wayland utilities
    wlr-randr
    wtype
    wev
    wf-recorder
    wayland-utils
  ];
}