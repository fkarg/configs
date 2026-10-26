---
description: Super-review. Use when you want a deep, multi-agent review of a branch or PR — fresh-context reviewer fleet, cross-model pass, production-readiness and a written architectural map — standalone (read-only; you decide fix-vs-note at the end) or as the review step of ic, modernize and takeover.
mode: primary
permission:
  bash: allow
  edit: allow
  webfetch: allow
  task:
    "*": allow
---

# Super Review

Comprehend a change, fan out fresh-context reviewers, check production-readiness, and return an architectural map plus one consolidated findings list.

**Two entry points.**

- **Standalone** (the user invoked it): run every step. Read-only — edit only when the user picks a fix at the checkpoint.
- **Called by a workflow** (ic, modernize, takeover): the caller supplies worktree, base, intent, plan, invariants, verification evidence and non-goals. Skip steps 1–2 except to fill gaps, skip the checkpoint, and return the findings, map, production report and its follow-ups. The caller fixes under its own authority and reruns the affected reviewers.

**Scale to the change.** A typo gets `reviewer` alone and a one-line verdict. When you skip a step, say so in one line.

## 1. Scope

`<base>` is the PR's base, otherwise the default branch (`git symbolic-ref refs/remotes/origin/HEAD`). Fetch origin and compute the diff:

- **PR named**: `gh pr view <n> --json title,body,headRefName,baseRefName` and `gh pr diff <n>`. A PR you only fetched is read-only — the checkpoint becomes report-only (optionally posted as PR comments).
- **Current branch** (default): diff against the branch-off point, not the base's moving tip (later commits on it would show up inverted): `git diff $(git merge-base origin/<base> HEAD)`. Standalone, do **not** stage anything; the user's index is not yours to touch. If `git status --porcelain` shows untracked files that belong to the change, read them directly and note that they're outside the diff. State which you reviewed: the branch as committed, or committed + uncommitted work.

Pull the intent from the linked issue/PR description, or ask the user for one line. Read the most-changed files yourself.

## 2. Comprehend

Dispatch in parallel: `explore` to map the touched area (one per distinct subsystem) and `understanding-prs-for-approval` on the diff for approval-grade comprehension (load-bearing invariants, cross-module call-chains, per-invariant test coverage).

When the change depends on an external API, evolving framework behavior, security guidance, a technical standard, or an architectural pattern whose suitability is in question, also dispatch a web-research subagent. It must seek official technical docs, standards, maintainers, and reputable independent technical sources—not SEO listicles, content farms, or agentic-system-generated material—and return cited findings that could change the review's judgment. Omit it only when the review is wholly local and the external context cannot affect a finding.

Synthesize in-thread: what the area does (`file:line`), the data flow the change touches, and the **invariants that must stay true** — these feed the fleet.

## 3. Review — fleet + cross-model

In one parallel wave, dispatch fresh-context reviewers who have not seen this conversation, each with the intent, plan if any, diff, invariants, test evidence and worktree path. Scale the roster; each agent's description says when it applies:

- Non-trivial changes: `reviewer`, `murphyjitsu-reviewer`, and `simplicity-reviewer` — called by ic, repeat it only if scope expanded, new abstractions appeared, or no cross-model peer is available, since ic ran it after green.
- When the change matches their trigger: `security-reviewer`, `test-quality-reviewer` (pass it the invariants), `performance-reviewer`, `consistency-reviewer`.

**Cross-model passes:** every dispatched reviewer runs its own lens pass (global peer rules), so the fleet is cross-model per lens. Give each reviewer what that pass needs: the base for the diff, the invariants and test evidence. Only when no fleet runs (a trivial change), run the generic pass yourself:

```
git diff $(git merge-base origin/<base> HEAD) | peer-review --stdin --mode diff-review --cd <worktree> \
  "Intent: <one line>. Invariants this must preserve: <list>. Tests run and their result: <summary>. Known non-goals: <list>."
```

A peer gets the invariants and test evidence, never a naked diff — otherwise it guesses what the change was meant to preserve, and guesses come back as noise. If peer-review reports no peer CLI, the same-model fleet, `simplicity-reviewer` included, is the only adversarial pass, so don't thin it.

Synthesize in-thread: dedupe, kill false positives, tag cross-model findings with the model that produced them, rank 🔴/🟡/🟢. `simplicity-reviewer` 🔴 findings are not advisory — they go to the checkpoint (or the caller) as their own block, not folded into nits. Record each peer finding's outcome per the global peer rules, tagged with its lens (or generic), in the synthesis that goes into the PR body — that is the record for judging which lens passes earn their cost.

## 4. Production readiness

For a non-trivial change, delegate to `production-readiness` with the same diff and worktree path. Called by a workflow, return its follow-ups to the caller. Standalone, route them per the target repo's AGENTS.md; filing an issue in another repo is outward-facing — confirm with the user first.

## 5. Architectural map

Build it in-thread from step 2 (or the caller's invariants), updated to what the review surfaced: what the change does and how (a paragraph); the invariants with coverage status (✓/⚠/✗, citing `test-quality-reviewer` when run, otherwise your own evidence); call-chains with `file:line`; where to look when X breaks; decisions and tradeoffs.

## 6. Checkpoint (standalone only) — the user decides fix-vs-note

Present: the architectural map, the synthesized findings (🔴/🟡/🟢, simplicity block separate), the production report. Then **wait**. Per finding the user picks **fix now** (only when the branch is local: apply, re-run the affected reviewer, update the map if an invariant moved) or **note** (report is the deliverable; offer to post PR comments — confirm before posting).

## Principles

- **Fresh eyes are the point.** Don't pre-bias the fleet with your own conclusions.
- **Synthesize, don't relay.** One deduped, ranked list beats seven raw reports.
- **Match the codebase.** Judge against the patterns in the same area, not personal preference.
