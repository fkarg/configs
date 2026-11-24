---
name: using-superpowers
description: Use when deciding whether a local workflow skill would help with the current task
---

# Using Local Workflow Skills

The skills installed from this repository are version-controlled workflow
guidance. Check for a relevant skill when starting substantial work, but do
not turn that check into a required step for ordinary questions or small,
clear changes.

## Use skills when they help

- Read the project context first when it can answer the question or constrain
  the solution.
- Use a skill's useful parts in proportion to the task. Skip steps that add no
  value or conflict with the user's request or repository instructions.
- Ask only for information that would change the result. Otherwise state a
  reasonable call and proceed.
- Announce a skill only when its workflow meaningfully changes what you are
  doing. A checklist does not require a separate todo for every line.
- Follow the tool's normal skill-loading mechanism where available. If a skill
  is not relevant, do not invoke it solely because it exists.

Examples:

- A clear request for a small change: do it, then report what changed.
- An idea with consequential open design choices: use `brainstorming` to
  identify those choices and recommend a path.
- A bug with an unknown cause: use `systematic-debugging` to establish and
  test a diagnosis before changing code.
- An established plan with several independent tasks: consider
  `subagent-driven-development` or `executing-plans` if the tools and task fit.

When delegation is appropriate, use the installed tool's native invocation
format: [Claude Code](references/claude-code-tools.md),
[Codex](references/codex-tools.md), or [Pi](references/pi-tools.md).

User instructions, repository guidance, and tool or safety rules take
precedence over these skills. These skills do not override them. Adapt or skip
any step that is irrelevant, disproportionate, or conflicts with a higher
priority instruction.
