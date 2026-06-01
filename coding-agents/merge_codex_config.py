#!/usr/bin/env python3
"""Overlay curated codex settings onto the local, codex-owned config.toml.

Codex (the CLI *and* the VS Code app-server) reads ``~/.codex/config.toml`` and
rewrites it in place — trusted ``[projects.*]``, ``oss_provider``, nux counters,
auth. That rules out a symlink (codex's atomic rename clobbers it) and we don't
want host-specific state in this public repo. So the coding_agents ansible role
runs this script to merge a small curated subset (``configs/codex/shared.toml``)
into the local file, leaving everything codex owns untouched.

The edit is deliberately *surgical*: it rewrites only the curated keys as raw
text and never reserialises the whole document, so codex's arbitrary host state
(quoted project-path tables, providers, counters) is preserved byte-for-byte.
Stdlib only — runs under the same system ``python3`` the role uses for build.py.

Usage:
    merge_codex_config.py [SHARED_TOML] [TARGET_CONFIG]
Defaults:
    SHARED_TOML   = <script dir>/configs/codex/shared.toml
    TARGET_CONFIG = ~/.codex/config.toml
"""

from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path


def _basic_string(s: str) -> str:
    esc = (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\t", "\\t")
        .replace("\r", "\\r")
    )
    return f'"{esc}"'


def _render(value) -> str:
    """Render a curated scalar/array to TOML text. Curated values are only ever
    strings, bools, ints/floats, or arrays of those — anything else is a bug in
    shared.toml and should fail loudly rather than corrupt the local config."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return _basic_string(value)
    if isinstance(value, list):
        return "[" + ", ".join(_render(v) for v in value) + "]"
    raise TypeError(f"unsupported curated value type: {type(value).__name__}")


def _key_line_re(key: str) -> re.Pattern[str]:
    return re.compile(r"^\s*" + re.escape(key) + r"\s*=")


def _header_indices(lines: list[str]) -> list[int]:
    return [i for i, line in enumerate(lines) if re.match(r"^\s*\[", line)]


def _set_top_level(lines: list[str], scalars: dict) -> None:
    """Replace/insert curated scalars in the preamble (before the first table)."""
    headers = _header_indices(lines)
    preamble_end = headers[0] if headers else len(lines)
    missing: list[str] = []
    for key, value in scalars.items():
        rendered = f"{key} = {_render(value)}"
        pat = _key_line_re(key)
        for i in range(preamble_end):
            if pat.match(lines[i]):
                lines[i] = rendered
                break
        else:
            missing.append(rendered)
    if missing:
        lines[preamble_end:preamble_end] = missing


def _set_table(lines: list[str], name: str, table: dict) -> None:
    """Replace/insert curated keys under ``[name]``, creating it if absent."""
    headers = _header_indices(lines)
    header_idx = next((i for i in headers if lines[i].strip() == f"[{name}]"), None)
    new_keys = [f"{key} = {_render(value)}" for key, value in table.items()]

    if header_idx is None:
        if lines and lines[-1].strip() != "":
            lines.append("")
        lines.append(f"[{name}]")
        lines.extend(new_keys)
        return

    block_end = next((i for i in headers if i > header_idx), len(lines))
    block = lines[header_idx + 1 : block_end]
    managed = [_key_line_re(key) for key in table]
    kept = [line for line in block if not any(pat.match(line) for pat in managed)]
    lines[header_idx + 1 : block_end] = new_keys + kept


def merge(shared_path: Path, target_path: Path) -> bool:
    curated = tomllib.loads(shared_path.read_text())
    scalars = {k: v for k, v in curated.items() if not isinstance(v, dict)}
    tables = {k: v for k, v in curated.items() if isinstance(v, dict)}

    original = target_path.read_text() if target_path.exists() else ""
    lines = original.splitlines()

    _set_top_level(lines, scalars)
    for name, table in tables.items():
        _set_table(lines, name, table)

    result = "\n".join(lines).strip("\n") + "\n"
    if result == original:
        return False
    target_path.parent.mkdir(parents=True, exist_ok=True)
    target_path.write_text(result)
    return True


def main(argv: list[str]) -> int:
    here = Path(__file__).resolve().parent
    shared = Path(argv[1]) if len(argv) > 1 else here / "configs" / "codex" / "shared.toml"
    target = Path(argv[2]).expanduser() if len(argv) > 2 else Path("~/.codex/config.toml").expanduser()
    changed = merge(shared, target)
    print(f"{'changed' if changed else 'unchanged'}: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
