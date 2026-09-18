#!/usr/bin/env python3
"""Overlay curated Claude preferences onto host-local settings.json.

The curated settings own the complete hooks object, so third-party installers
cannot make host-specific hooks leak back into the shared configuration. Other
objects merge recursively and preserve host-owned keys.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def is_adrafinil_hook_group(value) -> bool:
    return isinstance(value, dict) and any(
        isinstance(hook, dict) and hook.get("_adrafinil") is True
        for hook in value.get("hooks", [])
    )


def merge_hooks(current, curated, preserve_adrafinil_hooks: bool):
    if not preserve_adrafinil_hooks or not isinstance(current, dict):
        return curated

    result = {event: list(groups) for event, groups in curated.items()}
    for event, groups in current.items():
        if not isinstance(groups, list):
            continue
        adrafinil_groups = [group for group in groups if is_adrafinil_hook_group(group)]
        if adrafinil_groups:
            result[event] = adrafinil_groups + result.get(event, [])
    return result


def merge_value(current, curated, path=(), preserve_adrafinil_hooks=False):
    if path == ("hooks",):
        return merge_hooks(current, curated, preserve_adrafinil_hooks)
    if isinstance(current, dict) and isinstance(curated, dict):
        result = dict(current)
        for key, value in curated.items():
            result[key] = merge_value(current.get(key), value, (*path, key), preserve_adrafinil_hooks)
        return result
    return curated


def merge(shared_path: Path, target_path: Path, preserve_adrafinil_hooks: bool = False) -> bool:
    curated = json.loads(shared_path.read_text())
    current = json.loads(target_path.read_text()) if target_path.exists() else {}
    result = merge_value(current, curated, preserve_adrafinil_hooks=preserve_adrafinil_hooks)
    rendered = json.dumps(result, indent=2) + "\n"
    original = target_path.read_text() if target_path.exists() else ""
    if rendered == original:
        return False
    target_path.parent.mkdir(parents=True, exist_ok=True)
    target_path.write_text(rendered)
    return True


def main(argv: list[str]) -> int:
    here = Path(__file__).resolve().parent
    preserve_adrafinil_hooks = "--preserve-adrafinil-hooks" in argv
    args = [arg for arg in argv[1:] if arg != "--preserve-adrafinil-hooks"]
    shared = Path(args[0]) if args else here / "configs" / "claude" / "settings.json"
    target = Path(args[1]).expanduser() if len(args) > 1 else Path("~/.claude/settings.json").expanduser()
    changed = merge(shared, target, preserve_adrafinil_hooks)
    print(f"{'changed' if changed else 'unchanged'}: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
