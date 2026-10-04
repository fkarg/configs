"""Contract tests for the cross-model peer-review launcher.

The property that matters is routing on the *serving* model rather than the
harness: under Claudex the Claude Code harness is served by GPT, so a
harness-keyed rule would send GPT to Codex and call the result cross-model.
"""

from __future__ import annotations

import json
import os
import shutil
import signal
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

ANSWER = (
    '{"verdict":"challenges","findings":[],"counterproposal":"c",'
    '"attempted_falsifications":["tried x"],"unverified":[]}'
)

# Codex writes the bare answer to the file named by -o.
CODEX_STUB = f"""
printf '%s\\n' "$@" >"$RECORD_FILE"
printf 'base=%s\\n' "${{ANTHROPIC_BASE_URL:-unset}}" >>"$RECORD_FILE"
out=""
prev=""
for arg in "$@"; do
    case "$prev" in
        -o|--output-last-message) out="$arg" ;;
    esac
    prev="$arg"
done
printf '%s' '{ANSWER}' >"$out"
"""

# `claude -p --output-format json` emits the whole event stream as an ARRAY,
# and rejects a --json-schema that is a path rather than inline JSON. Both
# behaviours are reproduced here: asserting against a codex-shaped stub is
# what let a broken claude invocation ship.
CLAUDE_STUB = f"""
printf '%s\\n' "$@" >"$RECORD_FILE"
printf 'base=%s\\n' "${{ANTHROPIC_BASE_URL:-unset}}" >>"$RECORD_FILE"
prev=""
for arg in "$@"; do
    case "$prev" in
        --json-schema)
            case "$arg" in
                /*) printf 'Error: --json-schema is not valid JSON\\n' >&2
                    exit 1 ;;
            esac ;;
    esac
    prev="$arg"
done
printf '%s' '[{{"type":"system","subtype":"init"}},'
printf '%s' '{{"type":"result","subtype":"success","is_error":false,'
printf '%s' '"modelUsage":{{"claude-fable-5":{{"costUSD":0.1}}}},'
printf '%s' '"result":"{{}}","structured_output":{ANSWER}}}]'
"""

CATALOG_CODEX_STUB = """
[ "$*" = 'debug models' ] || exit 99
printf 'cli=codex\\n' >>"$RECORD_FILE"
printf '%s' '{"models":[{"slug":"visible-gpt","display_name":"Visible GPT","description":"Visible choice","visibility":"list"},{"slug":"hidden-gpt","display_name":"Hidden GPT","description":"Hidden choice","visibility":"hide"}]}'
"""

CATALOG_CLAUDE_STUB = """
[ "$*" = '-p --input-format stream-json --output-format stream-json --verbose --strict-mcp-config --no-session-persistence' ] || exit 99
printf 'cli=claude base=%s\\n' "${ANTHROPIC_BASE_URL:-unset}" >>"$RECORD_FILE"
python3 -c '
import json, sys
request = json.load(sys.stdin)
assert request["type"] == "control_request"
assert request["request"]["subtype"] == "initialize"
print(json.dumps({"type": "control_response", "response": {
    "subtype": "success", "request_id": request["request_id"], "response": {
        "account": {"email": "PRIVATE-ACCOUNT-MARKER"},
        "models": [{"value": "opus", "resolvedModel": "claude-test-id",
                    "displayName": "Opus", "description": "Claude choice"}]
    }}}))'
"""

RECORD_INPUT = 'printf "material:%s\\n" "$(cat)" >>"$RECORD_FILE"\n'


def write_executable(path: Path, body: str) -> None:
    path.write_text("#!/bin/sh\nset -eu\n" + body)
    path.chmod(0o755)


class PeerReviewTests(unittest.TestCase):
    def test_launcher_is_directly_executable(self) -> None:
        self.assertTrue(os.access(LAUNCHER, os.X_OK))

    def test_bare_call_ignores_open_inherited_stdin(self) -> None:
        """An open harness pipe used to hang in cat before launching a peer."""
        for family in ("gpt", "claude"):
            with self.subTest(family=family):
                proc, _, _ = self.run_launcher(
                    ["--from", family, "brief"], {}, open_stdin=True,
                )
                self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_material_requires_explicit_input(self) -> None:
        for family in ("gpt", "claude"):
            for explicit in (False, True):
                with self.subTest(family=family, explicit=explicit):
                    args = ["--from", family, "brief"]
                    if explicit:
                        args.insert(0, "--stdin")
                    proc, lines, _ = self.run_launcher(
                        args, {}, input_text="unique-material-ä\nsecond-line",
                        codex_stub=CODEX_STUB + RECORD_INPUT,
                        claude_stub=CLAUDE_STUB + RECORD_INPUT,
                    )
                    self.assertEqual(proc.returncode, 0, proc.stderr)
                    self.assertEqual("unique-material-ä" in "\n".join(lines), explicit)

    def test_file_material_does_not_read_inherited_stdin(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "material with spaces.md"
            path.write_text("file-material-ä\nsecond-line")
            for family in ("gpt", "claude"):
                for flag in ("-f", "--file"):
                    with self.subTest(family=family, flag=flag):
                        proc, lines, _ = self.run_launcher(
                            ["--from", family, flag, str(path), "brief"], {},
                            open_stdin=True,
                            codex_stub=CODEX_STUB + RECORD_INPUT,
                            claude_stub=CLAUDE_STUB + RECORD_INPUT,
                        )
                        self.assertEqual(proc.returncode, 0, proc.stderr)
                        self.assertIn(path.read_text(), "\n".join(lines))

    def test_input_sources_are_mutually_exclusive(self) -> None:
        proc, _, _ = self.run_launcher(
            ["--stdin", "-f", "file", "brief"], {}, open_stdin=True,
        )
        self.assertEqual(proc.returncode, 1)
        self.assertIn("cannot combine", proc.stderr)

    def test_unreadable_material_file_fails(self) -> None:
        proc, _, _ = self.run_launcher(
            ["-f", "/does-not-exist-peer-material", "brief"], {}, open_stdin=True,
        )
        self.assertEqual(proc.returncode, 1)
        self.assertIn("file", proc.stderr)

    def test_diff_review_requires_explicit_material(self) -> None:
        proc, _, _ = self.run_launcher(
            ["--mode", "diff-review", "brief"], {}, input_text="implicit diff",
        )
        self.assertEqual(proc.returncode, 1)
        self.assertIn("--stdin", proc.stderr)

    def test_target_models_preserve_alias_and_resolved_id_only(self) -> None:
        proc, _, _ = self.run_launcher(
            ["--mode", "models"], {"CODEX_THREAD_ID": "test"},
            claude_stub=CATALOG_CLAUDE_STUB, open_stdin=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        payload = json.loads(proc.stdout)
        self.assertEqual(set(payload), {"target"})
        self.assertEqual(payload["target"]["cli"], "claude")
        self.assertEqual(payload["target"]["models"], [{
            "id": "opus", "resolved_model": "claude-test-id",
            "display_name": "Opus", "description": "Claude choice",
        }])
        self.assertNotIn("PRIVATE-ACCOUNT-MARKER", proc.stdout + proc.stderr)

    def test_model_listing_can_include_self_and_catalog_visibility(self) -> None:
        proc, _, _ = self.run_launcher(
            ["--mode", "models", "--include-self"], {"CODEX_THREAD_ID": "test"},
            claude_stub=CATALOG_CLAUDE_STUB, codex_stub=CATALOG_CODEX_STUB,
            open_stdin=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        own = json.loads(proc.stdout)["self"]
        self.assertEqual(own["cli"], "codex")
        self.assertEqual([(m["id"], m["visibility"]) for m in own["models"]],
                         [("visible-gpt", "list"), ("hidden-gpt", "hide")])

    def test_claudex_model_listing_strips_proxy_only_for_target(self) -> None:
        proc, lines, _ = self.run_launcher(
            ["--mode", "models", "--include-self"],
            {"ANTHROPIC_BASE_URL": "http://127.0.0.1:8317"},
            claude_stub=CATALOG_CLAUDE_STUB, open_stdin=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(lines, ["cli=claude base=unset",
                                 "cli=claude base=http://127.0.0.1:8317"])

    def test_unknown_self_harness_is_not_guessed_from_family_override(self) -> None:
        proc, _, _ = self.run_launcher(
            ["--mode", "models", "--include-self", "--from", "gpt"], {},
            claude_stub=CATALOG_CLAUDE_STUB, open_stdin=True,
        )
        self.assertEqual(proc.returncode, 1)
        self.assertIn("harness", proc.stderr)

    def test_listing_rejects_review_input_and_include_self_requires_models(self) -> None:
        for args, error in ((["--mode", "models", "--stdin"], "does not accept"),
                            (["--mode", "models", "brief"], "does not accept"),
                            (["--include-self", "brief"], "requires --mode models")):
            with self.subTest(args=args):
                proc, _, _ = self.run_launcher(args, {}, open_stdin=True)
                self.assertEqual(proc.returncode, 1)
                self.assertIn(error, proc.stderr)

    def test_model_catalog_cli_failure_is_not_success(self) -> None:
        proc, _, _ = self.run_launcher(
            ["--mode", "models"], {"CODEX_THREAD_ID": "test"},
            claude_stub="exit 7\n", open_stdin=True,
        )
        self.assertEqual(proc.returncode, 1)
        self.assertIn("claude", proc.stderr)

    def test_model_discovery_error_does_not_echo_initialization_metadata(self) -> None:
        for response in (
            {"subtype": "error", "request_id": "peer-models",
             "error": "PRIVATE-ACCOUNT-MARKER"},
            {"subtype": "success", "request_id": "peer-models",
             "response": {"account": "PRIVATE-ACCOUNT-MARKER"}},
        ):
            with self.subTest(response=response["subtype"]):
                event = json.dumps({"type": "control_response", "response": response})
                proc, _, _ = self.run_launcher(
                    ["--mode", "models"], {"CODEX_THREAD_ID": "test"},
                    claude_stub=f"printf '%s\\n' '{event}'\n", open_stdin=True,
                )
                self.assertEqual(proc.returncode, 1)
                self.assertEqual(proc.stdout, "")
                self.assertNotIn("PRIVATE-ACCOUNT-MARKER", proc.stderr)

    def test_help_documents_actions_without_reading_stdin(self) -> None:
        for flag in ("-h", "--help"):
            with self.subTest(flag=flag):
                proc, _, _ = self.run_launcher([flag], {}, open_stdin=True)
                self.assertEqual(proc.returncode, 0, proc.stderr)
                for option in ("--stdin", "--file", "--include-self", "models"):
                    self.assertIn(option, proc.stdout)

    def run_launcher(
        self, args: list[str], env_overrides: dict[str, str],
        *, claude_stub: str = CLAUDE_STUB, codex_stub: str = CODEX_STUB,
        input_text: str | None = None, open_stdin: bool = False,
    ) -> tuple[subprocess.CompletedProcess[str], list[str], Path]:
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            bin_dir = tmpdir / "bin"
            bin_dir.mkdir()
            record = tmpdir / "record"

            write_executable(bin_dir / "codex", codex_stub)
            write_executable(bin_dir / "claude", claude_stub)

            # Prepend the stubs to the real PATH: this host is NixOS, so
            # /usr/bin carries no coreutils and a synthetic PATH loses grep.
            env = {
                "PATH": f"{bin_dir}:{os.environ['PATH']}",
                "HOME": str(tmpdir),
                "RECORD_FILE": str(record),
            }
            env.update(env_overrides)

            child = subprocess.Popen(
                [str(LAUNCHER), *args],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env,
                stdin=subprocess.PIPE,
                start_new_session=True,
            )
            try:
                if open_stdin:
                    child.wait(timeout=60)
                stdout, stderr = child.communicate(input_text, timeout=60)
                proc = subprocess.CompletedProcess(args, child.returncode, stdout, stderr)
            finally:
                if child.poll() is None:
                    os.killpg(child.pid, signal.SIGKILL)
                    child.communicate()
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
        """Regression: Codex calling Codex.

        A Codex-spawned shell exports CODEX_SESSION_ID / CODEX_THREAD_ID but
        NOT CODEX_HOME or CODEX_SANDBOX, so keying on the latter made every
        Codex session detect as Claude and select Codex as its own peer.
        """
        for var in ("CODEX_SESSION_ID", "CODEX_THREAD_ID"):
            with self.subTest(env=var):
                proc, _, _ = self.run_launcher(["brief"], {var: "abc123"})
                self.assertEqual(json.loads(proc.stdout)["peer_cli"], "claude")

    def test_codex_home_alone_does_not_imply_a_codex_session(self) -> None:
        """A shell that merely configures Codex is still Claude-served."""
        proc, _, _ = self.run_launcher(["brief"], {"CODEX_HOME": "/x/.codex"})
        self.assertEqual(json.loads(proc.stdout)["peer_cli"], "codex")

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

    def test_codex_peer_defaults_to_gpt_6_1_sol(self) -> None:
        proc, lines, _ = self.run_launcher(["--from", "claude", "brief"], {})
        self.assertIn("-m", lines)
        self.assertEqual(lines[lines.index("-m") + 1], "gpt-6.1-sol")
        self.assertEqual(json.loads(proc.stdout)["peer_model"], "gpt-6.1-sol")

    def test_result_reports_which_model_answered(self) -> None:
        proc, lines, _ = self.run_launcher(["--model", "gpt-5.6-sol", "brief"], {})
        self.assertEqual(lines.count("-m"), 1)
        self.assertEqual(lines[lines.index("-m") + 1], "gpt-5.6-sol")
        self.assertEqual(json.loads(proc.stdout)["peer_model"], "gpt-5.6-sol")

    def test_falsification_field_survives_to_the_caller(self) -> None:
        proc, _, _ = self.run_launcher(["brief"], {})
        result = json.loads(proc.stdout)["result"]
        self.assertEqual(result["attempted_falsifications"], ["tried x"])

    def test_claude_peer_gets_the_schema_inline_not_as_a_path(self) -> None:
        """Regression: a path made claude exit 1 on every peer call."""
        proc, lines, _ = self.run_launcher(["--from", "gpt", "brief"], {})
        self.assertEqual(proc.returncode, 0, proc.stderr)
        # The record is one line per argv entry and the schema spans lines,
        # so check where the inline JSON starts rather than reassembling it.
        schema_arg = lines[lines.index("--json-schema") + 1]
        self.assertNotEqual(schema_arg[:1], "/", "schema passed as a path")
        self.assertEqual(schema_arg.strip(), "{")
        self.assertIn("attempted_falsifications", "\n".join(lines))

    def test_claude_peer_defaults_to_opus_5_5(self) -> None:
        _, lines, _ = self.run_launcher(["--from", "gpt", "brief"], {})
        self.assertIn("--model", lines)
        self.assertEqual(lines[lines.index("--model") + 1], "claude-opus-5-5")

    def test_claude_peer_model_override_is_preserved(self) -> None:
        proc, lines, _ = self.run_launcher(
            ["--from", "gpt", "--model", "claude-sonnet-5", "brief"], {}
        )
        self.assertEqual(lines.count("--model"), 1)
        self.assertEqual(lines[lines.index("--model") + 1], "claude-sonnet-5")
        self.assertEqual(json.loads(proc.stdout)["peer_model"], "claude-fable-5")

    def test_claude_stdout_error_is_surfaced_on_nonzero_exit(self) -> None:
        """Real quota failures exit 1 with JSON on stdout and empty stderr.

        Previously the launcher deleted that JSON before parsing it, leaving
        only 'claude -p failed' and an empty stderr heading.
        """
        event = {
            "type": "result", "subtype": "success", "is_error": True,
            "api_error_status": 429, "result": "Synthetic model quota exhausted",
        }
        for payload in (event, [{"type": "system"}, event]):
            with self.subTest(event_array=isinstance(payload, list)):
                proc, _, _ = self.run_launcher(
                    ["--from", "gpt", "brief"], {},
                    claude_stub=f"printf '%s' '{json.dumps(payload)}'\nexit 1\n",
                )
                self.assertEqual(proc.returncode, 1)
                self.assertEqual(proc.stdout, "")
                self.assertIn("Synthetic model quota exhausted", proc.stderr)

    def test_claude_structured_error_details_are_surfaced(self) -> None:
        event = {
            "type": "result", "is_error": True,
            "subtype": "error_max_structured_output_retries",
            "errors": ["Synthetic schema validation failure"],
        }
        proc, _, _ = self.run_launcher(
            ["--from", "gpt", "brief"], {},
            claude_stub=f"printf '%s' '{json.dumps(event)}'\nexit 1\n",
        )
        self.assertEqual(proc.returncode, 1)
        self.assertIn("error_max_structured_output_retries", proc.stderr)
        self.assertIn("Synthetic schema validation failure", proc.stderr)

    def test_claude_nonzero_exit_cannot_be_reported_as_success(self) -> None:
        proc, _, _ = self.run_launcher(
            ["--from", "gpt", "brief"], {},
            claude_stub=CLAUDE_STUB + "\nexit 1\n",
        )
        self.assertEqual(proc.returncode, 1)
        self.assertEqual(proc.stdout, "")

    def test_claude_event_array_is_unwrapped(self) -> None:
        """claude --output-format json returns events, not one object."""
        proc, _, _ = self.run_launcher(["--from", "gpt", "brief"], {})
        payload = json.loads(proc.stdout)
        self.assertEqual(payload["result"]["verdict"], "challenges")
        self.assertEqual(payload["peer_model"], "claude-fable-5")

    def test_multiple_usage_models_do_not_misreport_a_helper(self) -> None:
        usage = {"claude-haiku-helper": {"outputTokens": 1},
                 "claude-opus-5-5": {"outputTokens": 300}}
        event = json.dumps({"structured_output": json.loads(ANSWER), "modelUsage": usage})
        for requested in ("claude-opus-5-5", "opus"):
            with self.subTest(requested=requested):
                proc, _, _ = self.run_launcher(
                    ["--from", "gpt", "--model", requested, "brief"], {},
                    claude_stub=f"printf '%s' '{event}'\n",
                )
                self.assertEqual(proc.returncode, 0, proc.stderr)
                self.assertEqual(json.loads(proc.stdout)["peer_model"], requested)

    def test_claude_peer_cannot_edit(self) -> None:
        _, lines, _ = self.run_launcher(["--from", "gpt", "brief"], {})
        self.assertIn("--disallowed-tools", lines)
        # The stub records the env probe after argv; drop that trailing line.
        denied = lines[lines.index("--disallowed-tools") + 1:-1]
        self.assertEqual(denied, ["Edit", "Write", "NotebookEdit"])

    def test_disallowed_tools_stays_last_so_it_swallows_nothing(self) -> None:
        """It is variadic: anything after it is eaten as a tool name.

        That is why the prompt goes on stdin rather than as a positional.
        """
        _, lines, _ = self.run_launcher(
            ["--from", "gpt", "--model", "m", "--cd", "/tmp", "brief"], {}
        )
        tail = lines[lines.index("--disallowed-tools"):]
        self.assertEqual(tail, ["--disallowed-tools", "Edit", "Write",
                                "NotebookEdit", "base=unset"])

    def test_peer_stderr_is_surfaced_on_failure(self) -> None:
        """An opaque failure is how the broken --json-schema flag survived."""
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            bin_dir = tmpdir / "bin"
            bin_dir.mkdir()
            write_executable(
                bin_dir / "codex",
                'printf \'quota exhausted, try later\\n\' >&2\nexit 1\n',
            )
            proc = subprocess.run(
                [str(LAUNCHER), "brief"],
                capture_output=True,
                text=True,
                env={
                    "PATH": f"{bin_dir}:{os.environ['PATH']}",
                    "HOME": str(tmpdir),
                },
                stdin=subprocess.DEVNULL,
                timeout=60,
            )
        self.assertEqual(proc.returncode, 1)
        self.assertIn("quota exhausted", proc.stderr)

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
    def test_piped_diff_examples_opt_in_to_stdin(self) -> None:
        for name in ("ic", "super-review", "understanding-prs-for-approval"):
            with self.subTest(agent=name):
                text = (REPO / "coding-agents" / "source" / f"{name}.md").read_text()
                self.assertIn("| peer-review --stdin --mode diff-review", text)

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
