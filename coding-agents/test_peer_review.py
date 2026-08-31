"""Contract tests for the cross-model peer-review launcher.

The property that matters is routing on the *serving* model rather than the
harness: under Claudex the Claude Code harness is served by GPT, so a
harness-keyed rule would send GPT to Codex and call the result cross-model.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parent.parent
LAUNCHER = REPO / "scripts" / "peer-review"
SHARED_AGENTS = REPO / "coding-agents" / "configs" / "shared" / "AGENTS.md"
ROLE_TASKS = (
    REPO / "ansible" / "roles" / "coding_agents" / "tasks" / "main.yml"
)

# A peer stub records how it was invoked, then emits a schema-shaped answer.
PEER_STUB = """
printf '%s\\n' "$@" >"$RECORD_FILE"
printf 'base=%s\\n' "${ANTHROPIC_BASE_URL:-unset}" >>"$RECORD_FILE"
payload='{"verdict":"challenges","findings":[],"counterproposal":"c",'
payload="$payload"'"attempted_falsifications":["tried x"],"unverified":[]}'
out=""
prev=""
for arg in "$@"; do
    case "$prev" in
        -o|--output-last-message) out="$arg" ;;
    esac
    prev="$arg"
done
if [ -n "$out" ]; then
    printf '%s' "$payload" >"$out"
else
    printf '%s' "$payload"
fi
"""


def write_executable(path: Path, body: str) -> None:
    path.write_text("#!/bin/sh\nset -eu\n" + body)
    path.chmod(0o755)


class PeerReviewTests(unittest.TestCase):
    def test_launcher_is_directly_executable(self) -> None:
        self.assertTrue(os.access(LAUNCHER, os.X_OK))

    def run_launcher(
        self, args: list[str], env_overrides: dict[str, str]
    ) -> tuple[subprocess.CompletedProcess[str], list[str], Path]:
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            bin_dir = tmpdir / "bin"
            bin_dir.mkdir()
            record = tmpdir / "record"

            for peer in ("codex", "claude"):
                write_executable(bin_dir / peer, PEER_STUB)

            # Prepend the stubs to the real PATH: this host is NixOS, so
            # /usr/bin carries no coreutils and a synthetic PATH loses grep.
            env = {
                "PATH": f"{bin_dir}:{os.environ['PATH']}",
                "HOME": str(tmpdir),
                "RECORD_FILE": str(record),
            }
            env.update(env_overrides)

            proc = subprocess.run(
                [str(LAUNCHER), *args],
                capture_output=True,
                text=True,
                env=env,
                stdin=subprocess.DEVNULL,
                timeout=60,
            )
            lines = (
                record.read_text().splitlines() if record.exists() else []
            )
            return proc, lines, tmpdir

    def test_plain_claude_session_routes_to_codex(self) -> None:
        proc, lines, _ = self.run_launcher(["brief"], {})
        self.assertEqual(proc.returncode, 0, proc.stderr)
        payload = json.loads(proc.stdout)
        self.assertEqual(payload["peer_cli"], "codex")
        self.assertEqual(payload["peer_family"], "gpt")

    def test_claudex_session_routes_to_claude_not_codex(self) -> None:
        """The regression this script exists to prevent: GPT reviewing GPT."""
        proc, lines, _ = self.run_launcher(
            ["brief"], {"ANTHROPIC_BASE_URL": "http://127.0.0.1:8317"}
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        payload = json.loads(proc.stdout)
        self.assertEqual(payload["peer_cli"], "claude")
        self.assertEqual(payload["peer_family"], "claude")

    def test_claude_peer_does_not_inherit_the_claudex_proxy(self) -> None:
        """A peer left pointed at the proxy would be GPT again."""
        _, lines, _ = self.run_launcher(
            ["brief"], {"ANTHROPIC_BASE_URL": "http://127.0.0.1:8317"}
        )
        self.assertIn("base=unset", lines)

    def test_codex_session_routes_to_claude(self) -> None:
        proc, _, _ = self.run_launcher(["brief"], {"CODEX_HOME": "/x/.codex"})
        payload = json.loads(proc.stdout)
        self.assertEqual(payload["peer_cli"], "claude")

    def test_explicit_from_overrides_detection(self) -> None:
        proc, _, _ = self.run_launcher(
            ["--from", "gpt", "brief"],
            {"ANTHROPIC_BASE_URL": "https://api.anthropic.com"},
        )
        self.assertEqual(json.loads(proc.stdout)["peer_cli"], "claude")

    def test_override_disagreeing_with_detection_is_flagged(self) -> None:
        """An unverifiable self-declaration can defeat the whole point."""
        proc, _, _ = self.run_launcher(
            ["--from", "gpt", "brief"],
            {"ANTHROPIC_BASE_URL": "https://api.anthropic.com"},
        )
        payload = json.loads(proc.stdout)
        self.assertIn("routing_warning", payload)
        self.assertEqual(payload["caller_family"], "gpt")

    def test_agreeing_override_carries_no_warning(self) -> None:
        proc, _, _ = self.run_launcher(["--from", "claude", "brief"], {})
        self.assertNotIn("routing_warning", json.loads(proc.stdout))

    def test_unrelated_local_relay_is_not_treated_as_claudex(self) -> None:
        """Only the Claudex endpoint is GPT; other local relays are Claude."""
        proc, _, _ = self.run_launcher(
            ["brief"], {"ANTHROPIC_BASE_URL": "http://127.0.0.1:9999"}
        )
        payload = json.loads(proc.stdout)
        self.assertEqual(payload["peer_cli"], "codex")
        self.assertNotIn("routing_warning", payload)

    def test_peer_runs_read_only_and_ephemeral(self) -> None:
        _, lines, _ = self.run_launcher(["brief"], {})
        self.assertIn("--sandbox", lines)
        self.assertIn("read-only", lines)
        self.assertIn("--ephemeral", lines)

    def test_peer_is_given_a_response_schema(self) -> None:
        _, lines, _ = self.run_launcher(["brief"], {})
        self.assertIn("--output-schema", lines)
        schema_path = lines[lines.index("--output-schema") + 1]
        # The schema is a temp file cleaned up on exit; assert the flag pairing
        # rather than its contents, which the end-to-end result already proves.
        self.assertTrue(schema_path)

    def test_result_reports_which_model_answered(self) -> None:
        proc, _, _ = self.run_launcher(["--model", "gpt-5.6-sol", "brief"], {})
        self.assertEqual(json.loads(proc.stdout)["peer_model"], "gpt-5.6-sol")

    def test_falsification_field_survives_to_the_caller(self) -> None:
        proc, _, _ = self.run_launcher(["brief"], {})
        result = json.loads(proc.stdout)["result"]
        self.assertEqual(result["attempted_falsifications"], ["tried x"])

    def test_rejects_unknown_mode(self) -> None:
        proc, _, _ = self.run_launcher(["--mode", "bogus", "brief"], {})
        self.assertEqual(proc.returncode, 1)
        self.assertIn("unknown mode", proc.stderr)

    def test_requires_a_brief(self) -> None:
        proc, _, _ = self.run_launcher([], {})
        self.assertEqual(proc.returncode, 1)

    def test_missing_peer_cli_fails_loudly(self) -> None:
        """A PATH carrying the shell utilities but neither peer CLI."""
        with tempfile.TemporaryDirectory() as tmp:
            utils = Path(tmp) / "utils"
            utils.mkdir()
            for tool in ("grep", "mktemp", "rm", "cat", "python3"):
                resolved = shutil.which(tool)
                self.assertIsNotNone(resolved, f"{tool} missing from PATH")
                (utils / tool).symlink_to(resolved)

            proc = subprocess.run(
                [str(LAUNCHER), "brief"],
                capture_output=True,
                text=True,
                env={"PATH": str(utils), "HOME": tmp},
                stdin=subprocess.DEVNULL,
                timeout=60,
            )
        self.assertEqual(proc.returncode, 1)
        self.assertIn("not installed", proc.stderr)


class PeerReviewWiringTests(unittest.TestCase):
    def test_shared_instructions_warn_about_harness_routing(self) -> None:
        text = SHARED_AGENTS.read_text()
        self.assertIn("peer-review", text)
        self.assertIn("serving model, not the harness", text)

    def test_role_symlinks_the_launcher_onto_path(self) -> None:
        text = ROLE_TASKS.read_text()
        self.assertIn("scripts/peer-review", text)
        self.assertIn("~/.local/bin/peer-review", text)

    def test_gate_workflows_invoke_the_launcher(self) -> None:
        source = REPO / "coding-agents" / "source"
        for name in (
            "ic",
            "super-review",
            "deploy-prep",
            "release-prep",
            "understanding-prs-for-approval",
        ):
            with self.subTest(agent=name):
                self.assertIn(
                    "peer-review", (source / f"{name}.md").read_text()
                )

    def test_specialist_reviewers_stay_single_model(self) -> None:
        """One peer call at the orchestrator; the fleet does not fan out."""
        source = REPO / "coding-agents" / "source"
        for name in (
            "reviewer",
            "security-reviewer",
            "performance-reviewer",
            "simplicity-reviewer",
            "test-quality-reviewer",
            "murphyjitsu-reviewer",
            "consistency-reviewer",
            "production-readiness",
        ):
            with self.subTest(agent=name):
                self.assertNotIn(
                    "peer-review", (source / f"{name}.md").read_text()
                )


if __name__ == "__main__":
    unittest.main()
