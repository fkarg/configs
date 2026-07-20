"""Tests for the portable Codex config merge."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("merge_codex_config.py")
SPEC = importlib.util.spec_from_file_location("merge_codex_config", MODULE_PATH)
assert SPEC and SPEC.loader
merge_codex_config = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(merge_codex_config)


class MergeCodexConfigTests(unittest.TestCase):
    def test_expands_home_relative_writable_roots(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            shared = temp_path / "shared.toml"
            target = temp_path / "config.toml"
            shared.write_text(
                "[sandbox_workspace_write]\n"
                'writable_roots = ["~/Coding/backend-core", "~/configs"]\n'
            )

            merge_codex_config.merge(shared, target)

            expected = [
                str(Path.home() / "Coding/backend-core"),
                str(Path.home() / "configs"),
            ]
            self.assertEqual(
                target.read_text(),
                "[sandbox_workspace_write]\n"
                f'writable_roots = ["{expected[0]}", "{expected[1]}"]\n',
            )


if __name__ == "__main__":
    unittest.main()
