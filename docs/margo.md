# Margo

The live entrypoint is `/etc/nixos/configuration.nix`, with hardware state kept
locally and shared modules imported through `/etc/nixos/configs`.
Keep `system.stateVersion = "24.11"`.

Margo uses GDM with Hyprland as the default session and PipeWire for audio.
The shared Hyprland config loads `dotconfig/hypr/margo.lua` through
`HYPRLAND_HOST_CONFIG`: the internal eDP panel uses its preferred mode at 1.5x,
and external displays use their preferred modes at 1x. This includes jolly's
ultrawide connected over USB-C; HDMI outputs remain available on margo.
The laptop Waybar config shows battery status instead of an NVIDIA GPU module.

Apply the session dotfiles locally with:

```sh
ansible-playbook ansible/site.yml -l margo --tags hyprland,waybar
```

Prepare system changes for the next boot:

```sh
sudo env NIXOS_REBUILD_NO_SYSTEMD_RUN=1 nixos-rebuild boot
```

The environment override bypasses the old systemd-run incompatibility during
the initial upgrade. Automatic upgrades also use `boot` and never reboot.
Keep the previous working i3/X11 generation available in the boot menu until
the Hyprland session has been checked on the laptop and the external display.
