"""Contract tests for the Ansible-managed Claudex launcher."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parent.parent
LAUNCHER = REPO / "scripts" / "claudex"
TASKS = REPO / "ansible" / "roles" / "coding_agents" / "tasks" / "main.yml"
CLAUDEX_TASKS = (
    REPO / "ansible" / "roles" / "coding_agents" / "tasks" / "claudex.yml"
)
PLUGIN_TASKS = (
    REPO
    / "ansible"
    / "roles"
    / "coding_agents"
    / "tasks"
    / "claude_codex_plugin.yml"
)
DEFAULTS = REPO / "ansible" / "roles" / "coding_agents" / "defaults" / "main.yml"
TEMPLATE = (
    REPO
    / "ansible"
    / "roles"
    / "coding_agents"
    / "templates"
    / "cliproxyapi.conf.j2"
)
CLAUDE_SETTINGS = REPO / "coding-agents" / "configs" / "claude" / "settings.json"


def write_executable(path: Path, body: str) -> None:
    path.write_text("#!/bin/sh\nset -eu\n" + body)
    path.chmod(0o755)


class ClaudexLauncherTests(unittest.TestCase):
    def test_launcher_is_directly_executable(self) -> None:
        self.assertTrue(os.access(LAUNCHER, os.X_OK))

    def launcher_environment(self, home: Path) -> dict[str, str]:
        bin_dir = home / "bin"
        local_bin_dir = home / ".local" / "bin"
        config_dir = home / ".config" / "cliproxyapi"
        state_dir = home / ".local" / "state" / "cliproxyapi"
        bin_dir.mkdir(parents=True)
        local_bin_dir.mkdir(parents=True)
        config_dir.mkdir(parents=True)
        state_dir.mkdir(parents=True)
        (config_dir / "client-key").write_text("fixture-client-key\n")
        (config_dir / "config.yaml").write_text("host: 127.0.0.1\n")
        (config_dir / "version").write_text("7.2.143\n")
        (state_dir / "running-version").write_text("7.2.143\n")

        write_executable(
            bin_dir / "curl",
            'printf \'%s\\n\' \'{"data":[{"id":"gpt-5.6-sol"}]}\'\n',
        )
        write_executable(
            local_bin_dir / "cliproxyapi",
            'printf \'unexpected proxy start\\n\' >&2\nexit 99\n',
        )
        write_executable(
            bin_dir / "claude",
            """
printf 'base=%s\n' "$ANTHROPIC_BASE_URL"
printf 'token=%s\n' "$ANTHROPIC_AUTH_TOKEN"
printf 'main=%s\n' "$ANTHROPIC_MODEL"
printf 'opus=%s\n' "$ANTHROPIC_DEFAULT_OPUS_MODEL"
printf 'sonnet=%s\n' "$ANTHROPIC_DEFAULT_SONNET_MODEL"
printf 'haiku=%s\n' "$ANTHROPIC_DEFAULT_HAIKU_MODEL"
printf 'first_party=%s\n' "$_CLAUDE_CODE_ASSUME_FIRST_PARTY_BASE_URL"
printf 'compact=%s\n' "$CLAUDE_CODE_AUTO_COMPACT_WINDOW"
printf 'args='
printf '<%s>' "$@"
printf '\n'
""",
        )

        env = os.environ.copy()
        env["HOME"] = str(home)
        env["PATH"] = f"{bin_dir}:/usr/bin:/bin"
        return env

    def test_routes_claude_harness_to_gpt56_tiers(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            home = Path(temp_dir)
            result = subprocess.run(
                ["/bin/sh", str(LAUNCHER), "--permission-mode", "plan"],
                env=self.launcher_environment(home),
                check=True,
                capture_output=True,
                text=True,
            )

        self.assertEqual(
            result.stdout.splitlines(),
            [
                "base=http://127.0.0.1:8317",
                "token=fixture-client-key",
                "main=claude-opus-4-8",
                "opus=claude-opus-4-8",
                "sonnet=claude-sonnet-5",
                "haiku=claude-haiku-4-5",
                "first_party=1",
                "compact=200000",
                "args=<--model><claude-opus-4-8><--effort><high>"
                "<--permission-mode><auto><--append-system-prompt>"
                "<Claudex compatibility notice: Claude model names are routing "
                "aliases, not your identity. claude-opus-4-8 routes to OpenAI "
                "GPT-5.6 Sol; claude-sonnet-5 and claude-sonnet-4-6 route to "
                "OpenAI GPT-5.6 Terra; claude-haiku-4-5 and "
                "claude-haiku-4-5-20251001 route to OpenAI GPT-5.6 Luna. "
                "Identify yourself as the routed OpenAI GPT-5.6 tier, never as "
                "Claude or Opus/Sonnet/Haiku.><--permission-mode><plan>",
            ],
        )

    def test_login_uses_the_proxy_device_flow(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            home = Path(temp_dir)
            env = self.launcher_environment(home)
            write_executable(
                home / ".local" / "bin" / "cliproxyapi",
                "printf '<%s>' \"$@\"\nprintf '\\n'\n",
            )

            result = subprocess.run(
                ["/bin/sh", str(LAUNCHER), "--login"],
                env=env,
                check=True,
                capture_output=True,
                text=True,
            )

        self.assertEqual(
            result.stdout,
            f"<-config><{home}/.config/cliproxyapi/config.yaml>"
            "<-codex-device-login>\n",
        )

    def test_missing_client_key_fails_without_starting_claude(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            home = Path(temp_dir)
            env = self.launcher_environment(home)
            (home / ".config" / "cliproxyapi" / "client-key").unlink()

            result = subprocess.run(
                ["/bin/sh", str(LAUNCHER)],
                env=env,
                capture_output=True,
                text=True,
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("run the coding_agents Ansible role", result.stderr)


class ClaudexProvisioningTests(unittest.TestCase):
    def test_proxy_template_is_loopback_only_and_maps_all_gpt56_tiers(self) -> None:
        template = TEMPLATE.read_text()
        self.assertIn('host: "127.0.0.1"', template)
        self.assertIn("allow-remote: false", template)
        self.assertIn('name: "gpt-5.6-sol"', template)
        self.assertIn('alias: "claude-opus-4-8"', template)
        self.assertIn('name: "gpt-5.6-terra"', template)
        self.assertIn('alias: "claude-sonnet-5"', template)
        self.assertIn('name: "gpt-5.6-luna"', template)
        self.assertIn('alias: "claude-haiku-4-5"', template)
        self.assertIn("{{ ca_claudex_proxy_key", template)
        self.assertNotIn("your-api-key", template)

    def test_release_is_pinned_for_caeli_and_jolly_architectures(self) -> None:
        defaults = DEFAULTS.read_text()
        self.assertIn('ca_claudex_version: "7.2.143"', defaults)
        self.assertIn("darwin_aarch64", defaults)
        self.assertIn(
            "ee3c7c0ddab05d6f348dbcce92bc2b1f6dfada76aa4abf40d12254edd3fd5e6e",
            defaults,
        )
        self.assertIn("linux_amd64", defaults)
        self.assertIn(
            "9154f460a5684ae82d74f3643d7b3f9c8961659d33058458c9edc044f5f761ba",
            defaults,
        )

    def test_archive_extraction_works_with_macos_bsd_tar(self) -> None:
        tasks = CLAUDEX_TASKS.read_text()
        extraction_task = tasks.split(
            "- name: Extract the pinned CLIProxyAPI release", 1
        )[1].split("- name:", 1)[0]
        self.assertIn("command:", extraction_task)
        self.assertIn("- tar", extraction_task)
        self.assertIn("- -xzf", extraction_task)
        self.assertIn('creates: "{{ ca_claudex_install_dir }}/cli-proxy-api"', extraction_task)
        self.assertNotIn("unarchive:", extraction_task)

    def test_ansible_keeps_credentials_out_of_output_and_is_host_gated(self) -> None:
        tasks = TASKS.read_text() + CLAUDEX_TASKS.read_text()
        self.assertIn("Install Claudex", tasks)
        self.assertIn("claudex_enabled | bool", tasks)
        self.assertIn("no_log: true", tasks)
        self.assertIn('dest: "~/.local/bin/claudex"', tasks)
        self.assertIn('dest: "~/.local/bin/cliproxyapi"', tasks)

        for host in ("caeli", "jolly"):
            host_vars = (
                REPO / "ansible" / "inventory" / "host_vars" / f"{host}.yml"
            ).read_text()
            self.assertIn("claudex_enabled: true", host_vars)

    def test_plugin_installation_matches_the_global_settings_scope(self) -> None:
        main_tasks = TASKS.read_text()
        plugin_tasks = PLUGIN_TASKS.read_text()
        self.assertIn("Check whether Claude Code is installed", main_tasks)
        self.assertIn("file: claude_codex_plugin.yml", main_tasks)
        self.assertNotIn("claude plugin", CLAUDEX_TASKS.read_text())
        self.assertIn("claude plugin marketplace add", plugin_tasks)
        self.assertIn("claude plugin install codex@openai-codex", plugin_tasks)
        self.assertNotIn("--yes", plugin_tasks)

    def test_check_mode_reuses_an_existing_proxy_key(self) -> None:
        tasks = CLAUDEX_TASKS.read_text()
        slurp_task = tasks.split("- name: Read the per-host Claudex proxy key", 1)[1]
        slurp_task = slurp_task.split("- name:", 1)[0]
        self.assertNotIn("when: not ansible_check_mode\n", slurp_task)
        self.assertIn("ca_claudex_proxy_key_path.stat.exists", slurp_task)

    def test_role_restarts_an_outdated_proxy_and_propagates_its_tag(self) -> None:
        main_tasks = TASKS.read_text()
        claudex_tasks = CLAUDEX_TASKS.read_text()
        self.assertIn("apply:\n      tags: [claudex]", main_tasks)
        self.assertIn("Stop an outdated Claudex proxy", claudex_tasks)
        self.assertIn("running-version", claudex_tasks)
        self.assertIn("proxy.pid", LAUNCHER.read_text())
        self.assertIn("running-version", LAUNCHER.read_text())

    def test_official_codex_plugin_is_declared(self) -> None:
        settings = json.loads(CLAUDE_SETTINGS.read_text())
        self.assertEqual(
            settings["extraKnownMarketplaces"]["openai-codex"]["source"],
            {"source": "github", "repo": "openai/codex-plugin-cc"},
        )
        self.assertIs(settings["enabledPlugins"]["codex@openai-codex"], True)


if __name__ == "__main__":
    unittest.main()
