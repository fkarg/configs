"""Exercise the status command against isolated VM state and a QMP socket."""

import contextlib
import json
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import threading
import unittest


class StatusTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "runner"
        shutil.copytree(
            Path(__file__).parent,
            self.root,
            ignore=shutil.ignore_patterns(".state", "__pycache__"),
        )
        self.state = self.root / ".state"

    def run_status(self, *arguments):
        return subprocess.run(
            ["bash", str(self.root / "vm"), "status", *arguments],
            capture_output=True,
            text=True,
            check=True,
            timeout=5,
        ).stdout

    def guest(self, instance):
        guest = self.state / str(instance)
        guest.mkdir(parents=True)
        (guest / "disk.qcow2").touch()
        return guest

    @contextlib.contextmanager
    def qmp(self, guest, status):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
            server.bind(str(guest / "qmp.sock"))
            server.listen(1)
            server.settimeout(2)

            def serve():
                try:
                    connection, _ = server.accept()
                except OSError:
                    return
                with connection:
                    connection.settimeout(2)
                    stream = connection.makefile("rwb")
                    with stream:
                        stream.write(b'{"QMP": {"capabilities": []}}\n')
                        stream.flush()
                        if json.loads(stream.readline())["execute"] != "qmp_capabilities":
                            return
                        stream.write(b'{"return": {}}\n')
                        stream.flush()
                        if json.loads(stream.readline())["execute"] != "query-status":
                            return
                        stream.write(b'{"event": "RESUME"}\n')
                        stream.write(json.dumps({"return": {"status": status}}).encode() + b"\n")
                        stream.flush()

            thread = threading.Thread(target=serve, daemon=True)
            thread.start()
            try:
                yield
            finally:
                thread.join(timeout=3)

    @staticmethod
    def rows(output):
        rows = [line.split() for line in output.splitlines()]
        return [row for row in rows if row and row[0].isdigit()]

    def test_empty_overview_does_not_create_state(self):
        self.assertIn("No local VM instances", self.run_status())
        self.assertFalse(self.state.exists())

    def test_overview_queries_qemu_and_sorts_instances_numerically(self):
        self.guest(10)
        running = self.guest(2)
        (running / "registered").touch()
        with self.qmp(running, "running"):
            output = self.run_status()
        self.assertEqual(
            self.rows(output),
            [["2", "running", "recorded", "127.0.0.1:2222", "0B"],
             ["10", "stopped", "none", "127.0.0.1:2230", "0B"]],
        )
        self.assertIn("local", output)
        self.assertIn("GitHub", output)

    def test_single_instance_does_not_include_others(self):
        self.guest(2)
        self.guest(3)
        self.assertEqual(self.rows(self.run_status("3")),
                         [["3", "stopped", "none", "127.0.0.1:2223", "0B"]])

    def test_stale_socket_is_not_reported_as_running(self):
        guest = self.guest(2)
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as stale:
            stale.bind(str(guest / "qmp.sock"))
        self.assertEqual(self.rows(self.run_status("2"))[0][1], "unreachable")

    def test_paused_vm_is_reported_as_paused(self):
        guest = self.guest(3)
        with self.qmp(guest, "paused"):
            self.assertEqual(self.rows(self.run_status("3"))[0][1], "paused")

    def test_missing_instance_does_not_create_state(self):
        self.assertEqual(self.rows(self.run_status("4")),
                         [["4", "not-created", "none", "127.0.0.1:2224", "-"]])
        self.assertFalse(self.state.exists())


if __name__ == "__main__":
    unittest.main()
