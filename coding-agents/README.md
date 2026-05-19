# coding-agents

Shared subagent / custom-agent definitions, synced across the four coding-agent
CLIs (OpenCode, Claude Code, Codex, GitHub Copilot CLI) by the `coding_agents`
Ansible role (`ansible/roles/coding_agents/`).

## Layout

```
source/<name>.md        canonical, opencode-flavored frontmatter (hand-edit here)
build.py                renders per-tool variants under generated/ (gitignored)
generated/              built each ansible run — do not edit
```

## Editing an agent

1. Edit `source/<name>.md`.
2. From `~/configs`, run:
   ```sh
   ansible-playbook ansible/site.yml -l <host> --tags coding-agents
   ```
3. Test in your tool.

The Ansible task runs `build.py`, then symlinks every variant into the right
global directory (`~/.config/opencode/agents/`, `~/.claude/agents/`,
`~/.codex/agents/`, `~/.copilot/agents/`).

## What gets translated

`build.py` reads the opencode-flavored frontmatter and emits per-tool files.
Permission semantics are the part that actually needs translation:

| opencode source             | Claude Code (`tools:`)            | Codex (`sandbox_mode`) | Copilot (`tools:`)        |
| --------------------------- | --------------------------------- | ---------------------- | ------------------------- |
| `edit: deny`                | drops Edit / Write / NotebookEdit | `read-only`            | drops `edit`              |
| `bash: deny`                | drops Bash                        | (n/a)                  | drops `execute`           |
| `webfetch: deny`            | drops WebFetch / WebSearch        | (n/a)                  | (n/a)                     |
| all `allow` (default)       | omit `tools:` → inherit           | omit → inherit         | omit `tools:` → inherit   |

`task:` (opencode's subagent-delegation control) has no clean cross-tool
analog and is left untranslated.

`mode: primary` / `mode: all` agents get installed everywhere as subagents
even though they were authored as opencode primary modes. They're still
invokable in the other tools; just don't expect them to behave as a "main mode".

## Removing an agent

Delete `source/<name>.md`. The matching symlinks in `~/.config/opencode/agents/`,
`~/.claude/agents/`, etc. won't be auto-removed — delete them by hand.
