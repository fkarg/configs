# Howdy / IR face-unlock setup — state & runbook (jolly)

Status as of last session: NixOS config is in place and switched live. The IR
**emitter** is not yet configured — `linux-enable-ir-emitter configure` failed
across all candidate sequences and asked for a reboot + manual mode. **Resume at
step 2 after a reboot.**

## Hardware (jolly)

SunplusIT integrated camera, four V4L2 nodes:

| Node | Role | Card |
|------|------|------|
| `/dev/video0` | RGB capture | Integrated C |
| `/dev/video1` | RGB metadata | Integrated C |
| `/dev/video2` | **IR capture** (Howdy uses this) | Integrated I |
| `/dev/video3` | IR metadata (not capturable — ignore its warnings) | Integrated I |

Stable symlink for the IR capture node:
`/dev/v4l/by-id/usb-SunplusIT_Inc_Integrated_Camera_01.00.00-video-index0` → `video2`.

Key finding: the IR sensor captures, but the IR **illuminator is off** — a raw
grab from `/dev/video2` comes back pitch black (mean pixel value 0). The emitter
must be enabled before Howdy can see anything.

## Config already applied

- `shared/security/howdy.nix` (new): enables `services.linux-enable-ir-emitter`
  (`device = "video2"`), enables `services.howdy` with `control = "sufficient"`
  (face OR password), and sets `settings.video.device_path` to the stable IR
  symlink above.
- `machines/jolly.nix`: imports `../shared/security/howdy.nix`.

`nixos-rebuild dry-build` passed; the system was switched live.

## Runbook

### 1. Rebuild (done)

```
sudo nixos-rebuild switch   # or: boot + reboot (jolly is normally boot-not-switch)
```

### 2. Configure the IR emitter  ← RESUME HERE (after a reboot)

The first attempt failed: under Wayland/Hyprland the GUI preview crashed
(`Can't initialize GTK backend` / `Authorization required`), so it was rerun
with `--no-gui`; every proposed sequence was answered "No", which ended with:

```
[ERROR] Impossible to reset the instruction: unit: 4, selector: 2, control: 0 32.
[INFO] Please shutdown your computer, then boot and retry.
[INFO] Please retry in manual mode by adding the '-m' option.
```

So: **reboot first**, then retry in manual mode + no-gui, pinned to video2:

```
sudo linux-enable-ir-emitter --device /dev/video2 configure -m --no-gui
```

- `-m` (manual): steps through controls one at a time instead of the automatic
  batch that just failed — more likely to find the right one.
- `--no-gui`: avoids the OpenCV/GTK preview window that can't open under
  root + Wayland.

For each candidate it asks **"Is the ir emitter flashing?"**. To *see* invisible
IR light: **point a phone camera at the lens** — IR LEDs show up as a bright
white/purple glow on the phone screen. Answer **Yes** only when it visibly
pulses.

If `--no-gui` manual mode still can't find it, options to try next:
- Increase attempts: add `-l -1` (unlimited negative answers) or `-e 2`
  (two emitters) — `configure -m --no-gui -l -1`.
- Grant root the display and use the GUI preview instead:
  ```
  xhost +SI:localuser:root
  sudo -E linux-enable-ir-emitter --device /dev/video2 configure -m
  ```
- Check upstream device notes: https://github.com/EmixamPP/linux-enable-ir-emitter

Verify the emitter independently of Howdy — capture a frame and confirm it's no
longer black (needs v4l-utils, e.g. `nix-shell -p v4l-utils`):

```
v4l2-ctl -d /dev/video2 --set-fmt-video=width=640,height=360,pixelformat=GREY \
  --stream-mmap --stream-count=1 --stream-to=/tmp/ir.raw
python3 -c "d=open('/tmp/ir.raw','rb').read(); print('mean', sum(d)/len(d))"
```

`mean` near 0 = still dark (emitter not working). A lit face should be well above 0.

### 3. Enroll a face and test Howdy

```
sudo howdy add        # capture a model for the current user
sudo howdy test       # live recognition check (needs the emitter working)
sudo howdy list       # list enrolled models
```

### 4. Confirm real auth

Open a fresh terminal and run `sudo -k; sudo true` — the camera should fire and
let you in without a password. It also applies at the GDM / Hyprland lock screen.
`control = "sufficient"` means face failures fall back to the password, so you
can't get locked out.

## Notes / caveats

- Even an IR cam can be fooled by a good photo — this is a convenience layer over
  the password, never a replacement.
- If `howdy test` shows a black frame, the emitter (step 2) isn't working — go
  back there.
