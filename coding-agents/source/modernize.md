---
description: Use when an old PR or issue's idea should land on today's codebase — re-derive the implementation against current main after a short interview on why it needs rewriting, what the focus is now, and what changes; or decide it should be closed.
mode: primary
permission:
  bash: allow
  edit: allow
  webfetch: allow
  task:
    "*": allow
---

<!-- Disposition and rebase guardrails adapted from t3dotgg/tstack (MIT): skills/modernize -->

# Modernize

Keep the idea, rewrite the technicals. A clean rebase does not prove the PR still belongs in the product, and an old diff is evidence of intent, not a spec. Input is a PR or issue number, as for `ic`.

## 1. Resolve the work

PR: record URL, state, base, head branch, head SHA, author, checks and review state. Issue: find its linked PRs (`closingIssuesReferences`, timeline cross-references) and branches named `<n>-*`; with several candidates, list them and ask which; with none, this is `ic` work. Someone else's PR goes to `takeover` instead. `git fetch origin`, then record the merge base so the original change and later base changes stay separable.

Check out the PR's branch in `.worktrees/<n>-<short-desc>`, unless the repo's AGENTS.md rules out worktrees. Modernizing authorizes rewriting and force-pushing that branch, nothing else: not merging, closing, retargeting, or growing scope.

## 2. Recover the idea

Read the issue, PR body, commits, review threads and the complete diff. Write the idea down without its implementation: the user outcomes it served, the invariants it relied on, what reviewers objected to. Old tests and fixtures usually state the intent best.

## 3. What changed around it

Dispatch `explore` per touched subsystem over `git log <merge-base>..origin/<base>` and the current code; search merged and open PRs for the same problem. Answer:

- Was the outcome already delivered, partly or fully?
- Did APIs, types, schemas, dependencies or ownership boundaries move?
- Was the code it changes deleted, moved or deliberately simplified?
- Would landing it restore old behavior or create a second way to do something?
- Is the benefit still worth its maintenance cost?

Run a blind `peer-review --mode premise --cd <worktree>` with the recovered idea and these facts, withholding your disposition.

## 4. Disposition and interview

Draft one:

- **REBASE** — the implementation is still the right shape: rebase, resolve conflicts by current intent and the base's newer invariants, compare `git range-diff` before/after, confirm nothing intended vanished and nothing already landed was reintroduced. A conflict that reveals a product or architecture disagreement reopens the disposition; don't guess.
- **REWRITE** — the idea stands but the old implementation fights today's code: re-derive it.
- **CLOSE** — superseded, obsolete or no longer worth it: cite evidence and stop without an interview. Age is not evidence; sunk effort is not a reason. Never close without permission.

For REBASE or REWRITE, one interview round of at most five questions, each with your recommended answer and the evidence behind it, covering what you cannot settle yourself:

- **Why rewrite:** what specifically breaks or degrades if the old approach is rebased as is?
- **Focus now:** which of the original outcomes still matter, which are dropped, what is newly important?
- **What changes:** behavior, interfaces or scope that should differ from the original.

Find facts yourself; ask only for decisions. Ask a follow-up round only when answers open a new fork. Record the answers; they become the PR's "what changed and why" section.

## 5. Plan and implement

REWRITE: present the plan as in `ic` — approach, files, change budget, non-goals, what carries over from the old diff (tests, fixtures, docs) and what is rewritten — and wait for sign-off. Implement from fresh `origin/<base>` on the PR branch; keep old commits only where they survive intact.

## 6. Review and ship

Take the result through `ic`'s review wave, verification artifacts and `commit`, with these differences: no issue assignment or new worktree; update the existing PR rather than opening one; push with `--force-with-lease=<branch>:<head SHA from step 1>`, and on a lease failure fetch and reassess. Rewrite the PR body: problem first, then the interview's "what changed and why", then the artifacts. Then load and follow `babysit`.

## Report

Lead with REBASE / REWRITE / CLOSE and the reason. Then: meaningful base changes, what carried over and what was dropped (with the interview answer behind it), the peer result and its disposition, push result, PR link, CI and review outcome. Separate observed facts from judgment.
