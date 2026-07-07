#!/usr/bin/env python3
"""Patch pi-powerline-footer until upstream exposes fresh post-compaction usage.

pi-powerline-footer 0.6.1 refreshes context usage on streaming/message/turn/tree
changes, but not on compaction/context rebuilds. After compaction its context_pct
segment can keep rendering the last pre-compaction assistant usage (e.g. 24%) even
while Pi's core ctx.getContextUsage() has dropped to the compacted value (<5%).

This patch is intentionally narrow and idempotent. It runs against the local npm
package installed under ~/.pi/agent/npm; if the package is missing or upstream has
changed, it exits cleanly with a note rather than breaking the Ansible role.
"""

from __future__ import annotations

import os
from pathlib import Path

HOME = Path.home()
TARGET = HOME / ".pi" / "agent" / "npm" / "node_modules" / "pi-powerline-footer" / "index.ts"

OLD = '''  pi.on("session_tree", async (_event, ctx) => {
    currentCtx = ctx;
    currentThinkingLevel = null;
    liveAssistantUsage = null;
    requestImmediateStatusRender({ deferDuringTyping: false });
  });

  // Generate themed working message before agent starts (has access to user's prompt)
'''

NEW = '''  pi.on("session_tree", async (_event, ctx) => {
    currentCtx = ctx;
    currentThinkingLevel = null;
    liveAssistantUsage = null;
    requestImmediateStatusRender({ deferDuringTyping: false });
  });

  pi.on("session_compact", async (_event, ctx) => {
    currentCtx = ctx;
    liveAssistantUsage = null;
    requestImmediateStatusRender({ deferDuringTyping: false });
    setTimeout(() => requestImmediateStatusRender({ deferDuringTyping: false }), 250);
    setTimeout(() => requestImmediateStatusRender({ deferDuringTyping: false }), 1000);
  });

  pi.on("context", async (_event, ctx) => {
    currentCtx = ctx;
    requestImmediateStatusRender({ deferDuringTyping: false });
  });

  // Generate themed working message before agent starts (has access to user's prompt)
'''


def main() -> int:
    if not TARGET.exists():
        print(f"skipped: {TARGET} not installed")
        return 0

    text = TARGET.read_text()
    if NEW in text:
        print(f"unchanged: {TARGET} already patched")
        return 0
    if OLD not in text:
        print(f"skipped: expected patch anchor not found in {TARGET}")
        return 0

    TARGET.write_text(text.replace(OLD, NEW, 1))
    print(f"changed: patched {TARGET}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
