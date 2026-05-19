#!/usr/bin/env python3
"""Transform canonical opencode agent definitions into per-tool formats.

Source: source/*.md  (opencode-flavored frontmatter, hand-edited canonical)
Outputs (regenerated each run):
    generated/claude/agents/<name>.md           (Claude Code subagent)
    generated/codex/agents/<name>.toml          (Codex CLI subagent)
    generated/copilot/agents/<name>.agent.md    (Copilot CLI custom agent)

Opencode reads the canonical source directly — no translation needed for it.

Permission translation is conservative: `edit: deny` and `webfetch: deny` in the
opencode source produce explicit restrictions in each target tool, so a
read-only reviewer stays read-only after sync. Anything unrecognised gets
logged as a warning rather than silently dropped.
"""

from __future__ import annotations

import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parent
SRC = REPO / "source"
OUT = REPO / "generated"

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n?(.*)$", re.DOTALL)

# Claude Code default tool universe; we subtract from this when permissions deny.
# Order is preserved in output for readability.
CLAUDE_DEFAULT_TOOLS = [
    "Read", "Glob", "Grep",
    "Edit", "Write", "NotebookEdit",
    "Bash",
    "WebFetch", "WebSearch",
    "Agent", "TodoWrite",
]
CLAUDE_EDIT_TOOLS = {"Edit", "Write", "NotebookEdit"}
CLAUDE_BASH_TOOLS = {"Bash"}
CLAUDE_WEB_TOOLS = {"WebFetch", "WebSearch"}

# Copilot CLI tool categories (per its docs).
COPILOT_ALL_TOOLS = ["read", "edit", "search", "execute"]


@dataclass
class Permissions:
    edit: str = "allow"       # "allow" | "ask" | "deny"
    bash: str = "allow"
    webfetch: str = "allow"


@dataclass
class Agent:
    name: str
    description: str
    mode: str
    permissions: Permissions
    body: str
    warnings: list[str]


def parse_frontmatter(text: str) -> tuple[dict, str]:
    """Stdlib YAML-ish parser for opencode frontmatter.

    Supports arbitrarily nested mappings via indent tracking, e.g.:

        permission:
          edit: deny
          bash:
            "*": allow
            "git push": ask
    """
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}, text

    raw, body = m.group(1), m.group(2)
    root: dict = {}
    # stack entries: (indent, container_dict)
    stack: list[tuple[int, dict]] = [(-1, root)]

    for line in raw.splitlines():
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        stripped = line.strip()
        if ":" not in stripped:
            continue
        key, _, value = stripped.partition(":")
        key = unquote(key.strip())
        value = value.strip()

        while stack and indent <= stack[-1][0]:
            stack.pop()
        container = stack[-1][1]

        if value:
            container[key] = unquote(value)
        else:
            new_map: dict = {}
            container[key] = new_map
            stack.append((indent, new_map))

    return root, body


def unquote(s: str) -> str:
    if len(s) >= 2 and s[0] == s[-1] and s[0] in ('"', "'"):
        return s[1:-1]
    return s


def coalesce_bash(raw) -> str:
    """opencode `bash` is either a string (allow/deny) or a mapping with `*` default."""
    if isinstance(raw, str):
        return raw or "allow"
    if isinstance(raw, dict):
        return raw.get("*", "allow")
    return "allow"


def load_agent(path: Path) -> Agent:
    fields, body = parse_frontmatter(path.read_text())
    perm_raw = fields.get("permission", {})
    if not isinstance(perm_raw, dict):
        perm_raw = {}

    warnings: list[str] = []
    # `task` controls whether the agent can spawn other subagents in opencode;
    # there's no clean cross-tool equivalent, so we accept it as known but skip translation.
    known_perm_keys = {"edit", "bash", "webfetch", "task"}
    for key in perm_raw:
        if key not in known_perm_keys:
            warnings.append(f"unknown permission key '{key}' (ignored)")

    permissions = Permissions(
        edit=perm_raw.get("edit", "allow") if isinstance(perm_raw.get("edit"), str) else "allow",
        bash=coalesce_bash(perm_raw.get("bash", "allow")),
        webfetch=perm_raw.get("webfetch", "allow") if isinstance(perm_raw.get("webfetch"), str) else "allow",
    )

    return Agent(
        name=path.stem,
        description=fields.get("description", "").strip() if isinstance(fields.get("description"), str) else "",
        mode=fields.get("mode", "subagent") if isinstance(fields.get("mode"), str) else "subagent",
        permissions=permissions,
        body=body,
        warnings=warnings,
    )


def claude_tools_for(perms: Permissions) -> list[str] | None:
    """Return an explicit allowlist when any deny is present; else None (inherit all)."""
    if perms.edit == "allow" and perms.bash == "allow" and perms.webfetch == "allow":
        return None

    allowed = list(CLAUDE_DEFAULT_TOOLS)
    if perms.edit == "deny":
        allowed = [t for t in allowed if t not in CLAUDE_EDIT_TOOLS]
    if perms.bash == "deny":
        allowed = [t for t in allowed if t not in CLAUDE_BASH_TOOLS]
    if perms.webfetch == "deny":
        allowed = [t for t in allowed if t not in CLAUDE_WEB_TOOLS]
    return allowed


def copilot_tools_for(perms: Permissions) -> list[str] | None:
    if perms.edit == "allow" and perms.bash == "allow":
        return None
    allowed = list(COPILOT_ALL_TOOLS)
    if perms.edit == "deny":
        allowed = [t for t in allowed if t != "edit"]
    if perms.bash == "deny":
        allowed = [t for t in allowed if t != "execute"]
    return allowed


def codex_sandbox_for(perms: Permissions) -> str | None:
    """Only emit sandbox_mode when restricting; otherwise inherit parent."""
    if perms.edit == "deny":
        return "read-only"
    return None


def claude_agent(agent: Agent) -> str:
    lines = ["---", f"name: {agent.name}", f"description: {agent.description}"]
    tools = claude_tools_for(agent.permissions)
    if tools is not None:
        lines.append(f"tools: {', '.join(tools)}")
    lines.append("---")
    return "\n".join(lines) + "\n\n" + agent.body.lstrip()


def codex_agent(agent: Agent) -> str:
    instructions = agent.body.lstrip().replace("\\", "\\\\").replace('"""', '\\"\\"\\"')
    lines = [
        f'name = "{toml_escape(agent.name)}"',
        f'description = "{toml_escape(agent.description)}"',
    ]
    sandbox = codex_sandbox_for(agent.permissions)
    if sandbox is not None:
        lines.append(f'sandbox_mode = "{sandbox}"')
    lines.append(f'developer_instructions = """\n{instructions}"""')
    return "\n".join(lines) + "\n"


def toml_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def copilot_agent(agent: Agent) -> str:
    lines = ["---", f"name: {agent.name}", f"description: {agent.description}"]
    tools = copilot_tools_for(agent.permissions)
    if tools is not None:
        rendered = ", ".join(f'"{t}"' for t in tools)
        lines.append(f"tools: [{rendered}]")
    lines.append("---")
    return "\n".join(lines) + "\n\n" + agent.body.lstrip()


def reset_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True)


def main() -> int:
    if not SRC.is_dir():
        print(f"source dir not found: {SRC}", file=sys.stderr)
        return 1

    claude_dir = OUT / "claude" / "agents"
    codex_dir = OUT / "codex" / "agents"
    copilot_dir = OUT / "copilot" / "agents"
    for d in (claude_dir, codex_dir, copilot_dir):
        reset_dir(d)

    count = 0
    for src in sorted(SRC.glob("*.md")):
        agent = load_agent(src)
        for warning in agent.warnings:
            print(f"warn  {agent.name}: {warning}", file=sys.stderr)

        (claude_dir / f"{agent.name}.md").write_text(claude_agent(agent))
        (codex_dir / f"{agent.name}.toml").write_text(codex_agent(agent))
        (copilot_dir / f"{agent.name}.agent.md").write_text(copilot_agent(agent))
        count += 1

    print(f"generated {count} agents into {OUT.relative_to(REPO)}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
