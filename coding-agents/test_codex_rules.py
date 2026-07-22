"""Tests for the shared Codex execution policy."""

from __future__ import annotations

import json
import subprocess
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
RULES = HERE / "configs" / "codex" / "rules" / "default.rules"
ANSIBLE_TASKS = HERE.parent / "ansible" / "roles" / "coding_agents" / "tasks" / "main.yml"


def decision_for(*command: str) -> str | None:
    result = subprocess.run(
        ["codex", "execpolicy", "check", "--rules", str(RULES), "--", *command],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout).get("decision")


class CodexRulesTests(unittest.TestCase):
    def test_allows_all_git_commands(self) -> None:
        self.assertEqual(decision_for("git", "status"), "allow")
        self.assertEqual(decision_for("git", "fetch", "origin", "main"), "allow")
        self.assertEqual(
            decision_for("git", "worktree", "add", ".worktrees/682-fix", "main"),
            "allow",
        )
        self.assertEqual(decision_for("git", "add", "app/example.ts"), "allow")
        self.assertEqual(decision_for("git", "commit", "-m", "test: example"), "allow")
        self.assertEqual(decision_for("git", "push", "origin", "HEAD"), "allow")
        self.assertEqual(
            decision_for("git", "fetch", "--upload-pack", "arbitrary-command", "origin"),
            "allow",
        )
        self.assertEqual(decision_for("git", "diff", "--ext-diff"), "allow")
        self.assertEqual(decision_for("git", "reset", "--hard"), "allow")
        self.assertEqual(decision_for("git", "clean", "-fd"), "allow")
        self.assertEqual(
            decision_for("git", "worktree", "remove", ".worktrees/example"),
            "allow",
        )

    def test_allows_read_only_github_commands(self) -> None:
        self.assertEqual(
            decision_for("gh", "issue", "view", "682", "--json", "body"),
            "allow",
        )
        self.assertEqual(decision_for("gh", "pr", "view", "687"), "allow")
        self.assertEqual(decision_for("gh", "auth", "status", "-h", "github.com"), "allow")

    def test_prompts_for_remote_github_mutations(self) -> None:
        self.assertEqual(
            decision_for("gh", "pr", "create", "--title", "Example"),
            "prompt",
        )
        self.assertEqual(
            decision_for("gh", "issue", "create", "--title", "Example"),
            "prompt",
        )

    def test_ansible_symlinks_the_rules_directory(self) -> None:
        tasks = ANSIBLE_TASKS.read_text()
        self.assertIn('src: "{{ coding_agents_source_dir }}/configs/codex/rules"', tasks)
        self.assertIn('dest: "~/.codex/rules"', tasks)
        self.assertIn("state: link", tasks)
        # The directory is symlinked whole so Codex's atomic rewrites of
        # default.rules round-trip through Git; it is not copied file-by-file.
        self.assertNotIn('dest: "~/.codex/rules/default.rules"', tasks)

    def test_ansible_replaces_an_existing_rules_directory_only_when_confirmed(self) -> None:
        tasks = ANSIBLE_TASKS.read_text()
        self.assertIn("Stat existing Codex approval rules path", tasks)
        self.assertIn("Remove existing Codex approval rules directory", tasks)
        self.assertIn("ca_codex_rules_path.stat.isdir", tasks)
        self.assertIn(
            "not (ca_codex_rules_path.stat.islnk | default(false))",
            tasks,
        )
        self.assertIn("confirm_overwrite | default(false) | bool", tasks)
        self.assertIn("not ansible_check_mode", tasks)


if __name__ == "__main__":
    unittest.main()
