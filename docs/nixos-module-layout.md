# Shared NixOS Layout

This repo is split by purpose first, not by whether something is technically called a "program" in NixOS.

The practical rule is:

- if you only need a package available system-wide, add it to one of the shared package lists under `nixos/shared/packages/`
- if you need to set NixOS module options such as `programs.*`, `services.*`, `fonts.*`, firewall openings, or session integration, add a dedicated module under the appropriate shared directory and import it from the relevant top-level entry point

## Where To Put A New Install

### Global CLI tools

Put them in `nixos/shared/packages/base-cli.nix`.

Examples:

- `ripgrep`
- `jq`
- `tmux`
- `gh`

### Global desktop applications

Put them in `nixos/shared/packages/desktop-apps.nix`.

This is also the right place for browsers that should appear in system desktop-entry selection and default-app pickers, because installing them through `environment.systemPackages` exposes their desktop files under the current system profile.

Examples:

- `firefox`
- `chromium`
- `thunderbird`
- `libreoffice-fresh`

### Desktop support and integration tools

Put desktop support packages in `nixos/shared/packages/desktop-integration.nix`.

This bucket is for packages that support the desktop session rather than being the main application you launch for work.

Examples:

- `pavucontrol`
- `networkmanagerapplet`
- `redshift`
- `file-roller`

### Gaming and Steam compatibility tools

Put reusable gaming support packages in `nixos/shared/packages/gaming-compat.nix`.

This bucket is for helper tools around Steam, Proton, overlays, and FHS compatibility rather than the Steam service/module configuration itself.

Examples:

- `steam-run`
- `protonup-qt`
- `mangohud`
- `goverlay`

### Global development tooling

Put it in `nixos/shared/packages/developer-tooling.nix`.

Examples:

- `clang`
- `cmake`
- `kubectl`
- `ansible-lint`

### Wayland-specific utilities

Put them in `nixos/shared/packages/wayland-tools.nix`.

Examples:

- `wlr-randr`
- `wf-recorder`
- `wev`

### System fonts

Put them in `nixos/shared/packages/system-fonts.nix`.

### Declarative program modules

If a package has meaningful NixOS module options, prefer a dedicated module instead of hiding that logic in a package list.

Put shared `programs.*` configuration in `nixos/shared/programs/`.

Examples:

- `programs.ausweisapp`
- future shared modules such as `programs.dconf`, `programs.gnupg.agent`, or similar module-driven setup

That also includes reusable gaming defaults built from module options rather than package lists, such as `nixos/shared/programs/steam-defaults.nix`.

### Machine-specific behavior

If something is only correct on one host, keep it in that machine module instead of forcing it into the shared layout.

Examples:

- GPU-specific setup
- desktop environment choice
- host-specific upgrade policy overrides
- host-specific update jobs and rollout cadence
- boot and storage details that are not genuinely shared

## Entry Points

- `nixos/programs.nix` is the shared global software entry point
- `nixos/shared/default-policy.nix` is the shared default policy entry point
- `nixos/pars.nix` is the shared `pars` user entry point

Those files are expected to stay as aggregators so the high-level import graph remains easy to read.

Shared defaults intentionally do not decide whether a machine auto-updates or runs channel-update cron jobs. That belongs in the relevant machine module.
