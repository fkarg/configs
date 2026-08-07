-- Hyprland Lua config (replaces the deprecated hyprlang hyprland.conf as of
-- Hyprland 0.55; the old syntax is dropped entirely a release or two later).
-- API reference: the shipped stubs at /run/current-system/sw/share/hypr/stubs/
-- (point your Lua LSP there for completions) and https://wiki.hypr.land/.

-- Don't live-reload when this (symlinked) file changes on disk, e.g. from a
-- `git pull` mid-session. Manual reload stays bound below (SUPER+SHIFT+R /
-- SUPER+Period -> `hyprctl reload`). Replaces the old top-level
-- `reload_on_file_change = false`.
hl.config({
    misc = {
        disable_autoreload = true,
    },
})

------------------
---- MONITORS ----
------------------

-- On this 32:9 setup the explicit 5120x1440@75 entries make the preferred
-- ultrawide mode obvious even when a display reports odd EDID data.
hl.monitor({ output = "DP-1", mode = "5120x1440@75", position = "auto", scale = 1.07 })
hl.monitor({ output = "DP-2", mode = "5120x1440@75", position = "auto", scale = 1.07 })
hl.monitor({ output = "DP-3", mode = "5120x1440@75", position = "auto", scale = 1.07 })
hl.monitor({ output = "DP-4", mode = "5120x1440@75", position = "auto", scale = 1.07 })
-- Fallback for any other connected monitor: pick the highest available mode.
hl.monitor({ output = "", mode = "highres", position = "auto", scale = 1.07 })
-- These outputs are intentionally disabled. Keep this when the GPU/monitor
-- exposes a ghost HDMI connector or a TV/AVR creates an unwanted desktop
-- surface.
hl.monitor({ output = "HDMI-A-1", disabled = true })
hl.monitor({ output = "HDMI-A-2", disabled = true })

-- Popular monitor variants to consider later:
-- - Force a primary-like position: hl.monitor({ output = "DP-1", mode = "5120x1440@75", position = "0x0", scale = 1 })
-- - HiDPI scaling:                 hl.monitor({ output = "DP-1", mode = "5120x1440@75", position = "0x0", scale = 1.25 })
-- - Mirror an output for capture:  hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1, mirror = "DP-1" })

---------------------
---- MY PROGRAMS ----
---------------------

-- --single-instance: all ad-hoc terminals share one process (one GPU sprite
-- cache) instead of ~50-220 MB VRAM each. NOT used for the lf window (would
-- strip its --class) or the dev session (single-instance ignores session
-- os_window_size). kitty.conf already sets allow_remote_control + listen_on.
local terminal    = "kitty --single-instance"
local fileManager = "dolphin"
local menu        = "fuzzel"

-- These variables keep keybindings readable. Swapping launchers or terminals is
-- then a one-line edit instead of touching every bind below.
-- Popular alternatives:
-- local terminal    = "foot"
-- local fileManager = "nautilus"
-- local menu        = "rofi -show drun"

-------------------
---- AUTOSTART ----
-------------------

-- The "hyprland.start" event fires only when Hyprland starts, not after every
-- reload (the Lua replacement for exec-once). Keep session-specific tools here
-- instead of systemd user services when they only work under a Hyprland
-- compositor.
hl.on("hyprland.start", function()
    hl.exec_cmd("mako")
    -- Load the hy3 layout only when its plugin is present in the system
    -- profile, i.e. when booted into jolly's `i2c-hy3` specialisation. Guarded
    -- by a file test so the default boot and other hosts sharing this config
    -- stay on dwindle without a missing-plugin error. hy3 gives reliable N-way
    -- tiled resize where dwindle's binary split-tree collapses columns for 3+
    -- windows.
    -- Done natively rather than by shelling out to hyprctl: `hyprctl keyword`
    -- does not exist under a Lua config ("keyword can't work with non-legacy
    -- parsers"), so the old sh guard silently left the layout on dwindle.
    local hy3_so = "/run/current-system/sw/lib/libhy3.so"
    local probe = io.open(hy3_so, "r")
    if probe then
        probe:close()
        hl.plugin.load(hy3_so)
        hl.config({ general = { layout = "hy3" } })
    end
    hl.exec_cmd("hyprlauncher -d")
    hl.exec_cmd("waybar -c ~/.config/waybar/hyprland.jsonc -s ~/.config/waybar/style.css")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprpolkitagent")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- Auto-dismiss mako notifications when the matching window gains focus.
    hl.exec_cmd("~/.config/hypr/notification-focus-dismiss.sh")
    -- Per-host startup window layout (hostname-guarded inside the script;
    -- currently jolly-only). Re-runnable by hand to restore the layout
    -- mid-session.
    hl.exec_cmd("~/.config/hypr/startup-apps.sh")

    -- Popular autostart additions:
    -- hl.exec_cmd("hyprpaper")
    -- hl.exec_cmd("udiskie --tray")
    -- hl.exec_cmd("copyq --start-server")
end)

---------------------
---- ENVIRONMENT ----
---------------------

-- Cursor settings are also set from Nix; keeping them here helps apps launched
-- inside Hyprland agree with the compositor.
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")

-- NVIDIA/Wayland knobs. Device selection is left automatic: the host has an AMD
-- Granite Ridge iGPU alongside the NVIDIA dGPU, but the iGPU is blacklisted at
-- the NixOS layer (jolly.nix: boot.blacklistedKernelModules += "amdgpu") so
-- aquamarine only ever sees the one GPU that drives the monitor. Without that
-- blacklist, multi-GPU buffer sharing flaked out (workspaces stuck at a
-- degraded resolution, windows flashing and vanishing); see that comment for
-- the detail.
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia")
hl.env("NVD_BACKEND", "direct")
-- If you ever need both GPUs live, do NOT set AQ_DRM_DEVICES to a
-- /dev/dri/by-path PCI name here: Aquamarine treats ':' as a device-list
-- separator, so pci-0000:01:00.0-card is split into invalid paths and Hyprland
-- aborts before the GDM session can register. Pin a verified /dev/dri/cardN
-- (or a ':'-free udev symlink to the NVIDIA node) instead, or re-check the
-- current Hyprland multi-GPU guidance first.
-- Electron apps should prefer Wayland where possible without forcing every app.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Steam runs under XWayland; with force_zero_scaling below it renders at native
-- pixels (crisp, no fractional-upscaling blur) but at 1x, so it looks ~7% small
-- on this 1.07-scaled output. Scale its client UI back up to match. Keep this
-- in sync with the monitor scale at the top of this file.
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1.07")

-- Popular environment options:
-- hl.env("MOZ_ENABLE_WAYLAND", "1")
-- hl.env("QT_QPA_PLATFORM", "wayland;xcb")
-- hl.env("SDL_VIDEODRIVER", "wayland")
-- hl.env("CLUTTER_BACKEND", "wayland")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    -- Render XWayland windows at native resolution instead of letting Hyprland
    -- upscale them to the fractional logical size. Without this, XWayland apps
    -- (Steam, many game launchers) are blurry and mis-scaled under the 1.07
    -- fractional output scale. Crisp at 1x; per-app scaling (e.g. Steam above)
    -- brings size back where wanted.
    xwayland = {
        force_zero_scaling = true,
    },

    general = {
        -- Inner gaps are between windows; outer gaps are between windows and
        -- screen edges. Small values keep the ultrawide usable without feeling
        -- cramped.
        gaps_in  = 3,
        gaps_out = 5,
        border_size = 2,

        -- Active border supports multiple colors and an angle. Inactive border
        -- is a single quiet gray so focus remains obvious.
        col = {
            active_border   = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        -- `dwindle` is the binary-tree tiling layout. `master` is also
        -- configured below and can be selected dynamically with hyprctl/layout
        -- binds.
        layout = "dwindle",

        -- Popular options:
        -- resize_on_border = true,
        -- hover_icon_on_border = true,
        -- extend_border_grab_area = 10,
    },

    decoration = {
        -- Rounded corners and opacity. 0 rounding is the sharp/tiled purist
        -- style; 8-12 is the common Hyprland look.
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,

        -- Popular visual options. Blur/shadow can look great, but can also be
        -- the first thing to disable while debugging NVIDIA/compositor
        -- weirdness.
        -- shadow = {
        --     enabled = true,
        --     range = 12,
        --     render_power = 3,
        -- },
        -- blur = {
        --     enabled = true,
        --     size = 4,
        --     passes = 2,
        --     vibrancy = 0.15,
        -- },
    },

    -- Disable all animations quickly with `enabled = false` if diagnosing
    -- latency, visual corruption, or motion sensitivity.
    animations = {
        enabled = true,
    },

    misc = {
        -- -1 keeps Hyprland's default wallpaper behavior. Set 0 to disable it.
        force_default_wallpaper = -1,
        disable_hyprland_logo = false,

        -- Prevent apps from stealing focus after a silent workspace move.
        focus_on_activate = false,
    },

    cursor = {
        -- Hardware cursors can be troublesome on some NVIDIA setups. This is
        -- left on for performance; flip to 1 if the cursor disappears or
        -- flickers.
        no_hardware_cursors = 0,
        -- CPU buffer helps avoid cursor format issues on some stacks.
        use_cpu_buffer = 1,
        enable_hyprcursor = false,

        -- Popular options:
        -- inactive_timeout = 5,
        -- hide_on_key_press = true,
    },

    dwindle = {
        -- Preserve the split direction when toggling or moving tiled windows.
        preserve_split = true,

        -- Popular dwindle options:
        -- smart_split = true,
        -- smart_resizing = true,
    },

    master = {
        -- If you switch to master layout, new windows become the master by
        -- default.
        new_status = "master",

        -- Popular master options:
        -- mfact = 0.55,
        -- new_on_top = true,
    },
})

-- Bezier curves are named easing functions used by the animation lines.
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },       { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 0.8,  bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 0.5,  bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 0.8,  bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

-- Popular calmer alternative:
-- hl.animation({ leaf = "windows",    enabled = true, speed = 3, bezier = "easeOutQuint" })
-- hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "easeOutQuint", style = "slide" })

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        -- German Neo layout by default. The B keybinds below switch between Neo
        -- and regular German without editing the file.
        kb_layout  = "de",
        kb_variant = "neo",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        -- Focus follows the pointer. Set 0 for click-to-focus, 2 for loose
        -- focus.
        follow_mouse = 1,
        -- Pointer acceleration; 0 means libinput default.
        sensitivity = 0,

        -- Popular input options:
        -- repeat_rate = 40,
        -- repeat_delay = 300,
        -- accel_profile = "flat",
        -- numlock_by_default = true,

        touchpad = {
            natural_scroll = false,
            -- Popular laptop options:
            -- tap_to_click = true,
            -- disable_while_typing = true,
            -- scroll_factor = 0.6,
        },
    },
})

-- Three-finger horizontal swipes move workspaces. If this conflicts with
-- browser gestures or touchpad habits, comment it out first.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Bind flag equivalents of the old bind forms:
-- - bind:  hl.bind(keys, dispatcher)
-- - bindm: { mouse = true }                    (mouse drag bind)
-- - bindel: { locked = true, repeating = true } (repeatable + works locked)
-- - bindl: { locked = true }                    (works on the lock screen)
-- - binde: { repeating = true }
-- - bindr: { release = true }
-- Modifiers combine inside the key string: "SUPER + SHIFT + X" etc.

-- Launchers and basic window control.
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + X", hl.dsp.window.close())
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + CTRL + E", hl.dsp.exec_cmd("kitty --class lf -e lf"))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + Z", hl.dsp.window.pseudo())

-- Popular extra app binds:
-- hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.exec_cmd("hyprlauncher"))
hl.bind(mainMod .. " + CTRL + Space", hl.dsp.exec_cmd("walker"))
hl.bind(mainMod .. " + ALT + Space", hl.dsp.exec_cmd("rofi -show drun"))
-- hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())

-- Keyboard layout switching. This changes Hyprland live state, not the config.
-- hl.bind takes a plain function, so these apply the change in-process instead
-- of shelling out to `hyprctl keyword`, which no longer exists under Lua.
hl.bind(mainMod .. " + B", function()
    hl.config({ input = { kb_layout = "de", kb_variant = "neo" } })
end)
hl.bind(mainMod .. " + SHIFT + B", function()
    hl.config({ input = { kb_layout = "de", kb_variant = "" } })
end)

-- Focus movement uses Neo-friendly N/M/G/D plus arrow-key fallbacks.
hl.bind(mainMod .. " + N", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + M", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + G", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + D", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + SHIFT + N", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- Layout control.
-- SUPER+H/T/W previously called `split h` / `split v` / `setlayout tabbed`,
-- carried over from the i3 config. Hyprland has no such dispatchers (and hy3
-- uses hy3:makegroup / hy3:changegroup), so they never did anything — dropped,
-- like the `focuswindow parent/child` binds before them. togglesplit is real
-- and stays.
hl.bind(mainMod .. " + L", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.layout("togglesplit"))
-- The old `focuswindow, parent` / `focuswindow, child` binds on SUPER+P and
-- SUPER+comma were dropped: `focuswindow` takes a window selector, so "parent"
-- was matched as a window class regex — i3-style parent/child focus does not
-- exist in Hyprland and these binds never did anything.

-- Popular layout binds:
-- hl.bind(mainMod .. " + Space", hl.dsp.window.float({ action = "toggle" }))
-- hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
-- hl.bind(mainMod .. " + Y", hl.dsp.group.toggle())

-- Scratchpad-style special workspace. Toggle shows/hides it; SHIFT moves the
-- focused window into it.
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Region screenshots copied directly to clipboard. `slurp` selects geometry,
-- `grim` captures it, and wl-copy stores PNG data.
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only -z"))
hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy --type image/png'))
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only -z"))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd('grim -g "$(slurp -d)" - | swappy -f -'))
hl.bind(mainMod .. " + CTRL + Print", hl.dsp.exec_cmd("hyprshot -m output --clipboard-only"))

-- Lock and suspend. Hypridle also calls the lock path before sleep.
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd("systemctl suspend"))

-- Config reload while staying in-session. Useful when editing this file.
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + Period", hl.dsp.exec_cmd("hyprctl reload"))

-- Workspace navigation. You have 20 numbered workspaces: 1-10 direct, 11-20 via
-- CTRL. On a 32:9 display this gives room for task-specific lanes. Switching
-- triggers on key release (old `bindr`); SHIFT moves the focused window there
-- without switching (old `movetoworkspacesilent` -> follow = false).
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,                  hl.dsp.focus({ workspace = i }),       { release = true })
    hl.bind(mainMod .. " + CTRL + " .. key,           hl.dsp.focus({ workspace = i + 10 }),  { release = true })
    hl.bind(mainMod .. " + SHIFT + " .. key,          hl.dsp.window.move({ workspace = i,      follow = false }))
    hl.bind(mainMod .. " + CTRL + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i + 10, follow = false }))
end

-- Jump back to the previously focused workspace.
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "previous" }))

-- Step through active (non-empty) workspaces one at a time. e-/e+ skip empty
-- ones, so this only ever lands on workspaces that currently have windows.
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "e+1" }))

-- Mouse wheel workspace switching while holding SUPER.
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Mouse drag move/resize while holding SUPER.
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media and brightness keys. locked+repeating repeats while held and works on
-- the lock screen, so volume/brightness remain available after locking.
hl.bind("XF86AudioRaiseVolume",   hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",   hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",          hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",       hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",    hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Popular media/screenshot additions:
hl.bind(mainMod .. " + CTRL + V", hl.dsp.exec_cmd("cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"))
-- hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd("brightnessctl -d '*::kbd_backlight' set +10%"), { locked = true, repeating = true })

-- Monitor KVM: send a DDC input-switch over the cable to flip the shared
-- monitor to the other machine (caeli). The script and target input code are
-- templated by ansible (see roles/graphical_dotfiles). Bind is inert until
-- hardware.i2c is re-enabled on this host — see nixos/machines/jolly.nix.
hl.bind("CTRL + SHIFT + F12", hl.dsp.exec_cmd("~/.config/hypr/kvm-switch.sh"))

-- Resize submap: SUPER+O enters resize mode, then N/G/M/D or arrows resize the
-- active window until Return or Escape resets back to normal binds.
-- (resize deltas keep the old resizeactive convention: +y grows downward)
hl.bind(mainMod .. " + O", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    hl.bind("N", hl.dsp.window.resize({ x = -10, y = 0,   relative = true }), { repeating = true })
    hl.bind("G", hl.dsp.window.resize({ x = 0,   y = 10,  relative = true }), { repeating = true })
    hl.bind("M", hl.dsp.window.resize({ x = 0,   y = -10, relative = true }), { repeating = true })
    hl.bind("D", hl.dsp.window.resize({ x = 10,  y = 0,   relative = true }), { repeating = true })
    hl.bind("left",  hl.dsp.window.resize({ x = -10, y = 0,   relative = true }), { repeating = true })
    hl.bind("down",  hl.dsp.window.resize({ x = 0,   y = 10,  relative = true }), { repeating = true })
    hl.bind("up",    hl.dsp.window.resize({ x = 0,   y = -10, relative = true }), { repeating = true })
    hl.bind("right", hl.dsp.window.resize({ x = 10,  y = 0,   relative = true }), { repeating = true })
    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("Escape", hl.dsp.submap("reset"))
end)

----------------------
---- WINDOW RULES ----
----------------------

-- Keeps `hyprland-run` helper windows floating and positions them near the
-- lower-left edge.
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Popular window-rule ideas to adapt:
--
-- Float file dialogs and pin them near the active area:
-- hl.window_rule({
--     name  = "float-dialogs",
--     match = { title = "^(Open File|Save File|Choose File)$" },
--     float = true,
--     center = true,
-- })
--
-- Put common apps on stable workspaces:
-- hl.window_rule({
--     name  = "browser-workspace",
--     match = { class = "firefox" },
--     workspace = 2,
-- })
--
-- Make picture-in-picture sticky, floating, and always on top:
-- hl.window_rule({
--     name  = "pip",
--     match = { title = "Picture-in-Picture" },
--     float = true,
--     pin = true,
--     keepaspectratio = true,
-- })

-------------------------
---- WORKSPACE IDEAS ----
-------------------------

-- Workspace rules are useful once you know which workspaces have stable jobs.
-- They are left commented so the current dynamic setup stays unchanged.
--
-- hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true })
-- hl.workspace_rule({ workspace = "2", monitor = "DP-1" })
-- hl.workspace_rule({ workspace = "special:magic", gaps_out = 20 })
-- hl.workspace_rule({ workspace = "10", on_created_empty = terminal })
