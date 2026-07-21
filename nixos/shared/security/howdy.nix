# Howdy face-unlock via the SunplusIT integrated IR camera.
#
# Hardware notes for this host (jolly):
#   /dev/video0  RGB capture     "Integrated Camera: Integrated C"
#   /dev/video1  RGB metadata
#   /dev/video2  IR  capture     "Integrated Camera: Integrated I"   <- Howdy
#   /dev/video3  IR  metadata
#
# The IR sensor captures fine on its own, but the IR *illuminator* ships
# disabled: a raw grab from /dev/video2 comes back pitch black (mean pixel
# value 0). Without light Howdy only ever sees a black frame, so the emitter
# must be switched on first. linux-enable-ir-emitter probes this specific
# camera over USB to find the vendor control transfer that powers the LED,
# then re-applies it on every boot via a systemd service ordered after the
# video2 device. It is configured interactively once, post-rebuild:
#
#     sudo linux-enable-ir-emitter configure
#
# After that, enroll a face and verify the camera:
#
#     sudo howdy add        # capture a face model for the current user
#     sudo howdy test       # live camera preview / recognition check
#     sudo howdy list       # list enrolled models
#
# control = "sufficient" makes a face match enough to authenticate on its own,
# with password entry as the fallback when recognition fails or times out
# (PAM falls through to the next module). The upstream module default is
# "required", which would instead demand face *and* password as 2FA.
#
# Security caveat carried over from the module docs: Howdy can be fooled by a
# good photo, and even an IR sensor is not a strong second factor. This is a
# convenience unlock layered on top of the password, never a replacement for
# it; the password path always remains available.
{ ... }:

{
  # Power on the IR emitter so the IR sensor sees an illuminated face rather
  # than a black frame. Run `sudo linux-enable-ir-emitter configure` once after
  # the first rebuild to generate the per-camera enabling sequence.
  services.linux-enable-ir-emitter = {
    enable = true;
    device = "video2";
  };

  services.howdy = {
    enable = true;

    # Face OR password: a match authenticates; failure falls back to password.
    control = "sufficient";

    settings.video = {
      # Stable per-camera symlink rather than the renumber-prone /dev/video2.
      # index0 is the IR capture node (index1 is its metadata sibling).
      device_path =
        "/dev/v4l/by-id/usb-SunplusIT_Inc_Integrated_Camera_01.00.00-video-index0";
    };
  };
}
