# # put here:
# modify config for i3status-rs (no battery, network)
# adapt fish/config (greet on desktop)
# add /HDD and /HDD3 to fstab
# add nvidia drivers
#
# modify startup script:
# - setting background
# - second screen config
{ config, pkgs, ... }:
{
  boot.loader.grub.device = ???

  networking.hostName = "home";

  networking.interfaces.
  networking.interfaces.
}

