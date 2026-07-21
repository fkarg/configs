# Hyprland Migration Guide

This guide is written for the current `jolly` migration from i3/X11 to Hyprland/Wayland.

It focuses on three things:

- what stays familiar from i3,
- what changes conceptually in Hyprland,
- and which companion tools you will likely want to pick to get back to a complete desktop.

## The Short Version

If you already know i3, Hyprland will feel familiar in these ways:

- it is keyboard-driven,
- workspaces still matter,
- focused window movement still matters,
- tiling layouts still matter,
- and you can build the desktop around your own chosen tools.

The important difference is this:

Hyprland is not "i3 but on Wayland".

It is closer to:

- a compositor,
- a tiling/window-management system,
- an IPC/control surface,
- plus a set of optional ecosystem tools.

That means the compositor itself handles more display/session behavior than i3 did, but it still does not provide a full desktop environment for you.

## What Stays The Same From i3

These habits transfer well.

### 1. Workspaces

Numbered workspaces remain the normal way to organize the session.

Typical carry-over:

- `Super+1..0` to switch workspaces
- `Super+Shift+1..0` to move a window to a workspace without following it there

That part of your current setup already maps cleanly.

### 2. Keyboard-centric focus and movement

Moving focus by direction and moving windows by direction are still first-class operations.

The mental model remains:

- focus a neighbor,
- move a window to a neighbor slot,
- enter a resize mode when needed.

### 3. Modes can become submaps

In i3, you had a resize mode.

In Hyprland, the nearest equivalent is a `submap`.

That means:

- enter a temporary keybinding layer,
- do a focused set of operations,
- return to normal mode.

So your i3 "resize mode" habit already has a natural Hyprland equivalent.

### 4. Rules still matter

i3 had assignments and behavior rules.

Hyprland uses:

- window rules,
- workspace rules,
- and monitor rules.

Same general idea, different vocabulary.

## What Changes In Hyprland

### 1. Layouts are not the same thing as i3 containers

Hyprland's common layouts are things like:

- `dwindle`
- `master`
- `tabbed`
- `monocle`
- `scrolling` depending on build/setup

Important difference:

- i3 is heavily container-tree oriented,
- Hyprland is more layout-dispatcher oriented.

You do not normally think in terms of manually building nested split containers the same way. You more often think in terms of:

- current layout,
- current split direction,
- current window rules,
- current workspace behavior.

### 2. More behavior is dynamic at runtime

`hyprctl` is a major part of the workflow.

You can use it to:

- inspect monitors,
- inspect clients,
- dispatch actions,
- reload config,
- set some keywords at runtime.

This makes Hyprland more interactive to explore than i3 if you lean into it.

Useful mindset:

- config defines your baseline,
- `hyprctl` lets you inspect and poke the running session.

### 3. Monitors are compositor-managed, not xrandr-managed

On X11, `xrandr` was the center of gravity.

On Hyprland/Wayland:

- static monitor layout should live in Hyprland config,
- runtime monitor changes can be handled by Hyprland itself or `wlr-randr`.

This is why old monitor scripts built around `xrandr` and `i3-msg` do not carry over well.

### 4. Bars, notifications, lock screen, and portal support are separate choices

This is the most important operational difference for a new Hyprland user.

You do not just install Hyprland and get a complete desktop.

You also need to choose:

- a bar,
- a lock screen,
- an idle daemon,
- a notification daemon,
- an authentication agent,
- and portal support.

That is why a session can be "visually working" while still feeling incomplete.

### 5. X11 compatibility still exists, but it should not be your design center

XWayland lets many older applications keep working.

That does not mean X11-era desktop plumbing is the right long-term choice for:

- screen locking,
- monitor management,
- screenshots,
- status bars,
- or launchers.

## A Good Baseline Stack For Jolly

This is the stack I would evaluate first.

For this repo, the current default direction should be:

- launcher: `fuzzel`
- lock screen: `hyprlock`
- idle daemon: `hypridle`
- bar: `waybar`
- notifications: `mako`
- auth agent: `hyprpolkitagent`
- screenshots: `grim` + `slurp`
- clipboard: `wl-clipboard` + `cliphist`
- audio/session plumbing: `pipewire` + `wireplumber`

That choice is pragmatic rather than ideological:

- `fuzzel` is a cleaner modern default than keeping `dmenu_run`, and lighter than richer launcher shells by default,
- `hyprlock` and `hypridle` fit the compositor you are actually using,
- `waybar` remains the least surprising bar choice,
- `mako` stays simpler than notification centers unless you specifically want one,
- and `pipewire` matches both Wayland screen sharing and the `wpctl`-based keybinds already present in your live config.

### Core session pieces

- compositor: Hyprland
- launcher: `fuzzel`, with `walker` as the richer alternative
- terminal: `kitty`
- file manager: Dolphin can stay

### Must-have companion services

- lock screen: `hyprlock` or `swaylock`
- idle daemon: `hypridle` or `swayidle`
- notifications: `mako` or `swaync`
- polkit agent: `hyprpolkitagent`
- portals: `xdg-desktop-portal` plus Hyprland portal backend
- audio/session plumbing: `pipewire` + `wireplumber`
- bar: `waybar`

### Nice-to-have utilities

- wallpapers: `hyprpaper`
- screenshots: `grim` + `slurp`
- clipboard history: `cliphist` + a launcher frontend
- color picker: `hyprpicker`
- brightness: `brightnessctl`
- session exit UI: `hyprshutdown`

## Replacements For Your Old i3 Tools

### Screen lock

Old:

- `i3lock-fancy`

Recommended replacements:

- `hyprlock`: best fit if you want Hyprland-native integration
- `swaylock`: mature and common Wayland choice

What changes:

- you typically pair it with `hypridle` or `swayidle` for idle lock and suspend behavior
- you stop treating lock as a standalone X11 script

### Status bar

Old:

- `i3bar` + `i3status-rs`

Recommended replacement:

- `waybar`

Why:

- it is the most common Wayland bar,
- has workspace/task/audio/network/bluetooth/tray modules,
- and can still run custom scripts for the special data you already expose.

Migration note:

- your custom scripts are still useful,
- but the bar host changes from i3bar to Waybar.

### Audio controls

Old:

- `pactl`

Wayland-era baseline:

- `wpctl` with PipeWire/WirePlumber

What changes:

- you stop thinking in terms of a standalone PulseAudio server as the center of the desktop.

### Network and Bluetooth tray/app control

Old assumptions:

- tray applets in an i3 bar or X11 tray world

Options now:

- keep `nm-applet` and `blueman` temporarily if they behave well under Wayland and the bar provides a tray,
- or move to Waybar modules plus explicit management tools.

Pragmatic advice:

- for migration speed, keeping `blueman` and `nm-applet` short-term is fine,
- but give them a real tray host in Waybar and do not build future config around X11-specific assumptions.

### Monitor control

Old:

- `xrandr`
- `i3-msg` workspace/output moves

New:

- Hyprland monitor config
- `wlr-randr` for runtime monitor changes
- optional Hyprland dispatches/scripts for workspace placement

### Launcher

Old:

- `dmenu_run`

New:

- `fuzzel`
- `walker`

Compatibility option:

- `wofi`

Practical guidance:

- `fuzzel` is the best modern default if you want something fast and minimal,
- `walker` is worth a look if you want a richer launcher later,
- `wofi` is still usable, but it now makes more sense as a compatibility choice than the default direction.

## What To Learn First In Hyprland

These are the parts worth learning early.

### 1. Layouts

Look into:

- `dwindle`
- `master`
- `tabbed`
- `monocle`

You will probably want to decide:

- which layout is your default,
- which layout you want available on-demand,
- and whether some workspaces should always use a specific layout.

For an i3 user, the most useful question is not "what is the prettiest layout?" It is:

"Which layout best matches how I actually group terminals, browsers, editors, and chat windows?"

### 2. Monitor rules

Look into Hyprland monitor configuration early.

This replaces a lot of what you previously delegated to `xrandr`.

Worth deciding:

- laptop-only behavior,
- docked/external display behavior,
- workspace-to-monitor conventions,
- scaling per display,
- and whether some monitors should be disabled in certain arrangements.

### 3. Window rules and workspace rules

These are high leverage.

Examples of what they solve well:

- make a window float,
- open an app on a specific workspace,
- set special behavior for launchers or scratchpad-like windows,
- control titlebar/border/opacity behavior,
- handle troublesome applications explicitly.

This is one of the best places to regain the feeling of a polished personal setup.

### 4. Submaps

If you liked i3 modes, learn submaps early.

Good candidates for submaps:

- resize mode,
- media/system actions,
- monitor actions,
- scratchpad/special workspace actions,
- session actions.

### 5. `hyprctl`

Learn these workflows early:

- inspect monitors
- inspect clients
- reload config
- dispatch layout/window actions
- test a keyword at runtime when possible

This is the quickest way to stop feeling blind inside Hyprland.

### 6. Special workspaces

Hyprland special workspaces are worth learning if you previously used scratchpad-like habits.

They can replace a lot of ad-hoc temporary window juggling.

### 7. Portals and screen sharing

This is boring but important.

If screen sharing, file pickers, or desktop capture behave strangely, the problem is often not Hyprland itself. It is usually the desktop portal setup.

That is why portal configuration belongs in the base desktop plan, not in a late cleanup pass.

## Advice On Your Current Hyprland State

The current session appears to be in the classic migration phase:

- enough binds exist to move around,
- some i3 muscle memory has already been ported,
- but the surrounding desktop is not yet coherent.

The main symptoms are exactly what you described:

- uncertain audio state,
- no clear Wayland-native replacement for lock/bar/add-ons,
- leftover X11-era assumptions,
- and not yet knowing which parts Hyprland itself owns.

That is normal for a first working visual generation.

The next improvement should not be hundreds of random new binds.

The next improvement should be choosing a complete Wayland desktop baseline and then cleaning the config around that baseline.

## A Sensible First-Round Hyprland Plan

If building the first proper Hyprland desktop for `jolly`, I would do it in this order:

1. Audio/session base: PipeWire + WirePlumber.
2. Lock/idle: `hyprlock` + `hypridle`.
3. Bar: `waybar`.
4. Notifications + polkit + portals.
5. Launcher and screenshot/clipboard tooling.
6. Monitor/workspace rules.
7. Then clean up binds and layout preferences.

That order matters because it gets you from "compositor starts" to "desktop is operable" before spending time on refinement.

## Recommended Alternatives To Evaluate

If you want a shortlist rather than a giant ecosystem survey, start here.

### Conservative set

- launcher: `wofi`
- lock: `swaylock`
- idle: `swayidle`
- bar: `waybar`
- notifications: `mako`

This is a very common Wayland stack and tends to be easy to reason about.

### Hypr-native set

- launcher: `fuzzel` or `walker`
- lock: `hyprlock`
- idle: `hypridle`
- bar: `waybar`
- notifications: `mako` or `swaync`
- auth agent: `hyprpolkitagent`
- wallpaper: `hyprpaper`
- shutdown dialog: `hyprshutdown`

This gives you tighter Hyprland integration and is probably the better long-term direction if you stay on Hyprland.

If choosing one concrete baseline rather than evaluating multiple near-equivalents, this repo should prefer:

- `fuzzel`
- `hyprlock`
- `hypridle`
- `waybar`
- `mako`
- `hyprpolkitagent`
- `grim` + `slurp`
- `wl-clipboard` + `cliphist`
- `pipewire` + `wireplumber`

## Hyprland Topics Worth Reading About

If you want to learn the system rather than cargo-cult a config, the most useful topic areas are:

- monitors
- binds
- dispatchers
- window rules
- workspace rules
- `hyprctl`
- XWayland
- environment variables
- multi-GPU
- performance
- the Hyprland ecosystem pages for `hyprlock`, `hypridle`, and the Hyprland portal

## Final Mental Model

Think of the migration like this.

### i3 world

- window manager: i3
- display control: Xorg + `xrandr`
- lock screen: `i3lock`
- bar: `i3bar`
- status generator: `i3status-rs`
- launcher: `dmenu`

### Hyprland world

- compositor/window manager: Hyprland
- display control: Hyprland monitor config and Wayland tools
- lock screen: `hyprlock` or `swaylock`
- idle: `hypridle` or `swayidle`
- bar: `waybar`
- status and integrations: Waybar modules plus scripts
- launcher: `wofi`, `fuzzel`, or `walker`
- portals/auth/notifications: explicit companion daemons

That is the key transition:

- some i3 habits stay,
- but the desktop plumbing around them has to be rebuilt for Wayland.
