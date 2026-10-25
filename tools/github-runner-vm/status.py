"""Read-only local VM overview; registration records are not GitHub status."""

import json
from pathlib import Path
import re
import socket
import sys


def vm_state(guest):
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(1)
            connection.connect(str(guest / "qmp.sock"))
            with connection.makefile("rwb") as stream:
                greeting = json.loads(stream.readline())
                if "QMP" not in greeting:
                    raise ValueError("Missing QMP greeting")
                for command in ("qmp_capabilities", "query-status"):
                    stream.write(json.dumps({"execute": command}).encode() + b"\n")
                    stream.flush()
                    while True:
                        response = json.loads(stream.readline())
                        if "error" in response:
                            raise ValueError("QMP command failed")
                        if "return" in response:
                            break
                return response["return"]["status"]
    except (FileNotFoundError, ConnectionRefusedError):
        # No socket, or one left behind by a QEMU that died (e.g. host crash).
        return "stopped" if (guest / "disk.qcow2").exists() else "not-created"
    except (OSError, ValueError, KeyError):
        return "unreachable"


state = Path(sys.argv[1])
selected = sys.argv[2]
instances = [state / selected] if selected else sorted(
    (guest for guest in state.glob("*")
     if guest.is_dir() and re.fullmatch(r"[1-9][0-9]?", guest.name)),
    key=lambda guest: int(guest.name),
)
if not instances:
    print("No local VM instances. Start one with ./vm start 1 inside nix-shell.")
    sys.exit(0)

print(f'{"INSTANCE":<10} {"VM":<14} {"REGISTRATION":<14} {"SSH":<22} DISK')
for guest in instances:
    try:
        allocated = (guest / "disk.qcow2").stat().st_blocks * 512
        disk = f"{allocated / 1024**3:.1f}GiB" if allocated else "0B"
    except FileNotFoundError:
        disk = "-"
    registration = "recorded" if (guest / "registered").exists() else "none"
    endpoint = f"127.0.0.1:{2220 + int(guest.name)}"
    print(f'{guest.name:<10} {vm_state(guest):<14} {registration:<14} '
          f'{endpoint:<22} {disk}')
print("\nRegistration is a local record; GitHub online/busy status is not queried.")
print("Disk shows allocated overlay space, excluding the shared Ubuntu base.")
