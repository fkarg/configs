# coding-agents

Shared subagent / custom-agent definitions, synced across the four coding-agent
CLIs (OpenCode, Claude Code, Codex, GitHub Copilot CLI) by the `coding_agents`
Ansible role (`ansible/roles/coding_agents/`).

## Layout

```
source/<name>.md        canonical, opencode-flavored frontmatter (hand-edit here)
build.py                renders per-tool variants under generated/ (gitignored)
generated/              built each ansible run — do not edit
configs/<tool>/         curated global settings, synced to ~/.<tool> (see below)
merge_codex_config.py   overlays curated codex prefs onto its local config.toml
```

## Codex account switching

`scripts/codex-account` snapshots file-based Codex credentials into
`~/.codex/account-auth/<profile>/auth.json` and swaps the active
`~/.codex/auth.json` between profiles. The `coding_agents` role links it to
`~/.local/bin/codex-account` and links `configs/codex/prompts/account.md` to
`~/.codex/prompts/account.md`, giving a slash-menu entry as `/prompts:account`.

Initial setup:

```sh
codex-account save personal
codex-account login business
codex-account use personal
```

Use `codex-account use personal` or `codex-account use business` to switch.
Restart the Codex CLI / IDE session after switching so the process reloads the
new credentials.

## Global tool settings (`configs/`)

Each tool's global config splits into two layers:

- **Curated, machine-independent prefs** — model, status line, permission
  *allowlists*, plugins. Tracked in `configs/<tool>/`.
- **Host-specific / secret state** — trusted project paths, providers, the
  logged-in identity, auth tokens. These stay in each tool's own local file and
  are **never** tracked (this repo is public). Auth is per-machine: log in once
  per host (`codex login`, etc.).

| Tool     | Tracked (curated)        | Synced to                          | Mechanism               | Local-only (untracked)                            |
| -------- | ------------------------ | ---------------------------------- | ----------------------- | ------------------------------------------------- |
| Claude   | `claude/settings.json`   | `~/.claude/settings.json`          | symlink                 | `~/.claude/settings.local.json`                   |
| OpenCode | `opencode/opencode.json` | `~/.config/opencode/opencode.json` | symlink                 | env-var secrets                                   |
| Copilot  | `copilot/settings.json`  | `~/.copilot/settings.json`         | symlink                 | `~/.copilot/config.json` (trustedFolders, login)  |
| Codex    | `codex/shared.toml`      | `~/.codex/config.toml`             | `merge_codex_config.py` | the rest of `~/.codex/config.toml`                |

Symlinks work for tools that only read the file or write it in place. **Codex is
different**: it atomically rewrites `~/.codex/config.toml` (a `rename()` that
clobbers a symlink) and mixes host state into it. So instead of a symlink,
`merge_codex_config.py` overlays just the keys from `codex/shared.toml` onto the
codex-owned local file, leaving trusted projects / `oss_provider` / nux intact.
Edit shared codex prefs in `codex/shared.toml`, then re-run the role to apply.

### Shared cross-tool prefs (`configs/shared/AGENTS.md`)

One source of global working-style preferences, symlinked into every tool's
global instructions file: `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and
`~/.config/opencode/AGENTS.md` (Codex and OpenCode auto-load a global
`AGENTS.md`; Claude uses `CLAUDE.md`). Edit it in one place and all three pick
it up on the next role run. This repo is public — keep it free of host-specific
or secret content.

## Creating a new agent or skill

Add ONE file — `source/<name>.md` — and apply it the same way as an edit (below).
Never hand-edit anything under `generated/`; it is rebuilt from source every run.

`<name>` (letters, numbers, hyphens) becomes the agent/skill name. The file is
opencode-flavored: YAML frontmatter + a markdown body that IS the agent's prompt.

| Frontmatter   | Values                                       | Notes                                                              |
| ------------- | -------------------------------------------- | ------------------------------------------------------------------ |
| `description` | string                                       | Start with "Use when…" — it's what each tool reads to decide when to pick this. |
| `mode`        | `subagent` (default) \| `primary` \| `all`   | **`primary` is the one that also produces a Skill** (see below).   |
| `permission`  | `edit`/`bash`/`webfetch`: `allow`\|`ask`\|`deny` | `bash` may instead be a map with a `"*"` default + per-command overrides; `task` gates subagent spawning (opencode-only). A `deny` becomes a real restriction in every tool — see *What gets translated*. |

**Skill vs. subagent — the choice that trips people up:**

- `mode: subagent` → installed only as a **subagent**: invoked by another agent via
  the Task/Agent tool, runs in its own context, can't pause to ask the user. Use for
  delegated, self-contained jobs (a reviewer, an implementer).
- `mode: primary` → ALSO rendered as a **Skill** for Claude Code + Codex. A skill
  runs in the **main thread**, so you invoke it directly (`/<name>`) and it can pause
  for clarifying questions / sign-off while still delegating to subagents. **Want a
  `/slash` skill you drive in a workflow? set `mode: primary`.** (Mechanics: *What gets translated*.)

Minimal skill template:

~~~md
---
description: Use when <triggering situation> — <symptoms / context>.
mode: primary
permission:
  bash: allow
  edit: deny       # read-only analyst; set allow for an agent that writes code
  webfetch: deny
---

# <Title>

<The prompt: the method to follow and the output to produce, written as
instructions to the agent.>
~~~

Then apply as below and confirm the variants landed under `generated/` and the
symlink appeared in `~/.claude/skills/<name>/` (and `~/.codex/skills/<name>/`).

## Editing an agent

1. Edit `source/<name>.md`.
2. From `~/configs`, run:
   ```sh
   ansible-playbook ansible/site.yml -l <host> --tags coding-agents
   ```
3. Test in your tool.

The Ansible task runs `build.py`, then symlinks every variant into the right
global directory (`~/.config/opencode/agents/`, `~/.claude/agents/`,
`~/.codex/agents/`, `~/.copilot/agents/`, plus `~/.claude/skills/` and
`~/.codex/skills/` for `mode: primary` agents).

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

`mode: primary` agents additionally get rendered as a **Skill**
(`generated/{claude,codex}/skills/<name>/SKILL.md`, same content for both —
Claude Code and Codex CLI share the SKILL.md format) and symlinked to
`~/.claude/skills/<name>/` and `~/.codex/skills/<name>/`. Unlike a subagent, a
skill runs in the main thread, so it can pause for interactive checkpoints
(plan sign-off, clarifying questions) while still delegating to specialist
subagents via the Agent/Task tool — this is how `ic` becomes usable as a
"baseline" workflow in tools that have no primary-mode concept. OpenCode needs
no skill (native primary mode); Copilot has no skill output yet.

## Removing an agent

Delete `source/<name>.md`. The matching symlinks in `~/.config/opencode/agents/`,
`~/.claude/agents/`, etc. won't be auto-removed — delete them by hand.
