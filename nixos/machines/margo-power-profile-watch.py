"""Reapply margo's CPU policy when the power source or profile changes."""

import os
import subprocess
import sys

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib


def main():
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    loop = GLib.MainLoop()

    def apply(*_):
        if subprocess.call(sys.argv[1:]) != 0:
            # D-Bus callbacks otherwise swallow exceptions. Let systemd restore
            # defaults and restart us instead of leaving a stale policy applied.
            os._exit(1)

    def owner_changed(_name, _old_owner, new_owner):
        if new_owner:
            apply()

    for name, path in [
        ("org.freedesktop.UPower.PowerProfiles", "/org/freedesktop/UPower/PowerProfiles"),
        ("org.freedesktop.UPower", "/org/freedesktop/UPower"),
    ]:
        bus.add_signal_receiver(
            apply,
            signal_name="PropertiesChanged",
            dbus_interface="org.freedesktop.DBus.Properties",
            bus_name=name,
            path=path,
            arg0=name,
        )
        bus.add_signal_receiver(
            owner_changed,
            signal_name="NameOwnerChanged",
            dbus_interface="org.freedesktop.DBus",
            bus_name="org.freedesktop.DBus",
            arg0=name,
        )

    # Subscribe first so a transition during the initial apply is not lost.
    apply()
    loop.run()


if __name__ == "__main__":
    main()
