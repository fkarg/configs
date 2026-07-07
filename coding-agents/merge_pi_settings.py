#!/usr/bin/env python3
"""Overlay curated Pi settings onto ~/.pi/agent/settings.json."""

from __future__ import annotations

import json
import sys
from pathlib import Path


MANAGED_POWERLINE_CUSTOM_ITEM_IDS = {"fkarg-loc", "fkarg-quota"}
RETIRED_POWERLINE_CUSTOM_ITEM_IDS = {"fkarg-status"}


def custom_item_id(item):
    if isinstance(item, dict):
        value = item.get("id")
        if isinstance(value, str):
            return value
    return None


def merge_powerline_custom_items(current, curated):
    if not isinstance(current, list) or not isinstance(curated, list):
        return curated

    managed_ids = MANAGED_POWERLINE_CUSTOM_ITEM_IDS | RETIRED_POWERLINE_CUSTOM_ITEM_IDS
    merged = [item for item in current if custom_item_id(item) not in managed_ids]
    for item in curated:
        if item not in merged:
            merged.append(item)
    return merged


def merge_value(current, curated, path=()):
    if isinstance(current, dict) and isinstance(curated, dict):
        merged = dict(current)
        for key, value in curated.items():
            merged[key] = merge_value(current.get(key), value, (*path, key))
        return merged
    if isinstance(current, list) and isinstance(curated, list):
        if path == ("powerline", "customItems"):
            return merge_powerline_custom_items(current, curated)
        merged = list(current)
        for item in curated:
            if item not in merged:
                merged.append(item)
        return merged
    return curated


def merge(shared_path: Path, target_path: Path) -> bool:
    curated = json.loads(shared_path.read_text())
    current = json.loads(target_path.read_text()) if target_path.exists() else {}
    result = merge_value(current, curated)
    rendered = json.dumps(result, indent=2, sort_keys=False) + "\n"
    original = target_path.read_text() if target_path.exists() else ""
    if rendered == original:
        return False
    target_path.parent.mkdir(parents=True, exist_ok=True)
    target_path.write_text(rendered)
    return True


def main(argv: list[str]) -> int:
    here = Path(__file__).resolve().parent
    shared = Path(argv[1]) if len(argv) > 1 else here / "configs" / "pi" / "shared.json"
    target = Path(argv[2]).expanduser() if len(argv) > 2 else Path("~/.pi/agent/settings.json").expanduser()
    changed = merge(shared, target)
    print(f"{'changed' if changed else 'unchanged'}: {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
