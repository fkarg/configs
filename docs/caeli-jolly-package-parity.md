# caeli ↔ jolly package parity

Living reference mapping **caeli** (personal Mac, Homebrew — `ansible/inventory/host_vars/caeli.yml`)
to **jolly** (NixOS tower — shared package modules pulled in via `nixos/programs.nix` plus
`nixos/machines/jolly.nix`).

It is not meant to reach 100%: some caeli entries are macOS-only helpers with no Linux
counterpart, and a few Linux gaps have no packaged equivalent. This table records what maps to
what, so the two hosts don't silently drift.

Sources of truth:
- caeli: `brew_packages_common` + `brew_casks_common` in `host_vars/caeli.yml`.
- jolly: `nixos/shared/packages/{base-cli,desktop-apps,desktop-integration,developer-tooling,wayland-tools,system-fonts}.nix`
  and `nixos/machines/jolly.nix` `environment.systemPackages`.

## CLI parity

Almost complete. The shared `base-cli.nix` / `developer-tooling.nix` modules already carry the
whole shell + dev toolchain (bat, eza, fzf, ripgrep(-all), zellij, zoxide, gh, git, lazygit,
tokei, ghc, node, bun, pnpm, uv, rustup, docker, the k8s tools, beancount suite, ansible, …).

| caeli (brew) | jolly (nixpkgs) | note |
|---|---|---|
| node@24 | `nodejs_24` | |
| rust | `rustup` | |
| kubernetes-cli | `kubectl` | |
| minio-mc | `minio-client` | |
| gemini-cli | `gemini-cli` | |
| tinymist | `tinymist` | in `desktop-apps.nix` |
| actionlint | `actionlint` | |
| ansible-lint | `ansible-lint` | |
| yamllint | `yamllint` | **added** |
| ghostscript | `ghostscript` | **added** |
| xpipe | `xpipe` | **added** |
| ccusage | — | npm-only, not in nixpkgs; installed via bun global if needed |
| pi-coding-agent | — | not in nixpkgs; provided through `coding-agents/` tooling |

## GUI parity

| caeli cask | jolly (nixpkgs) | note |
|---|---|---|
| whatsapp | `karere` | gtk4 whatsapp client |
| microsoft-teams | `teams-for-linux` | |
| google-chrome | `google-chrome` (wayland override) | |
| (n/a) | `chromium` (wayland override) | jolly ships both chrome + chromium |
| libreoffice | `libreoffice-fresh` | |
| element | `element-desktop` | **added** |
| ollama-app | `ollama` | |
| proton-mail | `protonmail-desktop` | |
| protonvpn | `proton-vpn` | |
| proton-pass | `proton-pass` | |
| mark-text | `marktext` | |
| copilot-cli | (via bun/npm global) | not from nixpkgs |
| openlogi | `hardware.logitech.wireless.{enable,enableGraphical}` (jolly.nix) | Logitech mgr (solaar) + udev rules; logi-options+ dropped on both |
| comfyui | — | not installed (not wanted yet) |
| proton-drive | — | no native Linux client (web only) |

## macOS-only on caeli — jolly analogue (not a 1:1 package)

| caeli | jolly approach |
|---|---|
| m1ddc | `ddcutil` (installed; drives the Ctrl+Shift+F12 KVM bind) |
| stats | `btop` |
| caffeine | hypridle / `systemd-inhibit` |
| raycast | rofi/wofi launcher (Hyprland) |
| karabiner-elements | Hyprland binds / keyd |
| sleepwatcher | systemd sleep hooks |
| amethyst / rectangle | Hyprland tiling (dwindle / hy3) |
| scroll-reverser | libinput natural-scroll |
| docker-desktop | docker engine directly (`virtualisation.docker`) |
| utm | libvirt/qemu (not set up on jolly) |
| batt, pngpaste | N/A (Apple-silicon / pasteboard specific) |
| microsoft-{word,excel,powerpoint,outlook} | libreoffice / web |

## No mapping (intentionally absent on jolly)

betterdiscord-installer, youtube-to-mp3, pear-desktop, tor-browser is present, microsoft
office casks — covered above.
