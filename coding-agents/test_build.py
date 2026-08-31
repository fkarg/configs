"""Contract tests for per-tool agent rendering."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("build.py")
SPEC = importlib.util.spec_from_file_location("agent_build", MODULE_PATH)
assert SPEC and SPEC.loader
agent_build = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = agent_build
SPEC.loader.exec_module(agent_build)


class ClaudeAgentRenderingTests(unittest.TestCase):
    def render(self, name: str) -> str:
        return agent_build.claude_agent(agent_build.load_agent(MODULE_PATH.parent / "source" / f"{name}.md"))

    def test_task_permission_controls_claude_delegation(self) -> None:
        ic = agent_build.load_agent(MODULE_PATH.parent / "source" / "ic.md")
        self.assertIsNone(agent_build.claude_tools_for(ic.permissions))
        self.assertNotIn("Agent", self.render("reviewer").split("\n", 4)[3])


if __name__ == "__main__":
    unittest.main()
