# kitty global watcher: when a window gains focus, dismiss the desktop
# notifications that originated from that window.
#
# Motivation: running several Claude Code sessions in separate kitty windows,
# each raises a desktop notification when it wants attention. Navigating to the
# session that caused one should clear it, instead of leaving a pile of stale
# notifications where it's unclear which are still relevant.
#
# Why this works on macOS at all: there is no public API to dismiss an
# arbitrary app's notifications. But kitty *owns* these (Claude posts them via
# preferredNotifChannel=kitty, i.e. the OSC 99 protocol) and internally tracks
# each notification's originating window as `channel_id`. So we can close
# precisely the ones a given window raised.
#
# This pokes kitty internals (boss.notification_manager + NotificationCommand
# fields), verified against kitty 0.47.1. The access is defensive: if a future
# kitty renames these, focus handling silently no-ops (set the debug env var
# below to see why) and nothing else about the window breaks.
#
# Debug: launch a throwaway kitty with KITTY_DISMISS_NOTIF_DEBUG=1 and redirect
# stderr to a file, e.g.
#   KITTY_DISMISS_NOTIF_DEBUG=1 /Applications/kitty.app/Contents/MacOS/kitty 2>/tmp/kitty-notif.log
# then grep that file for "[dismiss-notif]".

from __future__ import annotations

import os
from typing import Any

DEBUG = os.environ.get("KITTY_DISMISS_NOTIF_DEBUG") == "1"


def _log(*args: Any) -> None:
    if not DEBUG:
        return
    try:
        from kitty.utils import log_error

        log_error("[dismiss-notif]", *args)
    except Exception:
        pass


def _manager(boss: Any) -> Any:
    """Locate the NotificationManager hanging off the Boss instance."""
    try:
        from kitty.notifications import NotificationManager
    except Exception as e:  # pragma: no cover - kitty internals moved
        _log("cannot import NotificationManager:", e)
        return None
    mgr = getattr(boss, "notification_manager", None)
    if isinstance(mgr, NotificationManager):
        return mgr
    for value in getattr(boss, "__dict__", {}).values():
        if isinstance(value, NotificationManager):
            return value
    _log("no NotificationManager on boss")
    return None


def _find_commands(manager: Any) -> list[tuple[str, Any]]:
    """Find every NotificationCommand kitty is currently tracking.

    Active notifications may be tracked directly on the manager or on one of
    its collaborator objects (e.g. the macOS desktop integration). Attribute
    names are not public API, so scan the manager and its object-valued
    attributes one level deep for dicts holding NotificationCommands.
    """
    try:
        from kitty.notifications import NotificationCommand
    except Exception as e:  # pragma: no cover
        _log("cannot import NotificationCommand:", e)
        return []

    found: list[tuple[str, Any]] = []
    seen: set[int] = set()

    def scan(obj: Any, prefix: str) -> None:
        for attr, value in getattr(obj, "__dict__", {}).items():
            if isinstance(value, dict):
                for key, cmd in value.items():
                    if isinstance(cmd, NotificationCommand) and id(cmd) not in seen:
                        seen.add(id(cmd))
                        found.append((f"{prefix}.{attr}[{key!r}]", cmd))

    scan(manager, "mgr")
    for attr, value in getattr(manager, "__dict__", {}).items():
        if hasattr(value, "__dict__") and not isinstance(value, dict):
            scan(value, f"mgr.{attr}")
    return found


def on_focus_change(boss: Any, window: Any, data: dict) -> None:
    if not data.get("focused"):
        return
    window_id = getattr(window, "id", None)
    manager = _manager(boss)
    if manager is None:
        _log("focus window", window_id, "-> no manager")
        return

    commands = _find_commands(manager)
    if DEBUG:
        _log("focus window", window_id, "- tracked notifications:", len(commands))
        for where, cmd in commands:
            _log(
                "  ",
                where,
                "channel_id=", getattr(cmd, "channel_id", "?"),
                "desktop_id=", getattr(cmd, "desktop_notification_id", "?"),
                "identifier=", repr(getattr(cmd, "identifier", "?")),
                "done=", getattr(cmd, "done", "?"),
                "created_by_desktop=", getattr(cmd, "created_by_desktop", "?"),
            )

    targets = [
        getattr(cmd, "desktop_notification_id", 0)
        for _, cmd in commands
        if getattr(cmd, "channel_id", None) == window_id
        and getattr(cmd, "desktop_notification_id", 0)
    ]
    closed = 0
    for desktop_notification_id in targets:
        try:
            manager.close_notification(desktop_notification_id)
            closed += 1
        except Exception as e:  # pragma: no cover
            _log("close failed for", desktop_notification_id, e)
    if DEBUG or closed:
        _log("focus window", window_id, "-> closed", closed, "notification(s)")
