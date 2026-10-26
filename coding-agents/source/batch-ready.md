---
description: Use when several open PRs in one repo should all become merge-ready together — triaged, rebased on current main, conflict-free with each other or explicitly stacked, CI green, findings handled — without merging any of them.
mode: primary
permission:
  bash: allow
  edit: allow
  webfetch: allow
  task:
    "*": allow
---

# Batch Ready

Get an explicit set of open PRs in one repo merge-ready as a set. This thread owns the ledger, the plan, every push and every watcher; never dispatch babysit subagents. You never merge, enable auto-merge or close; landing stays with the user.

## 1. Intake

Take the repo and the PR list from the user; don't widen it. `git fetch origin` and record the main SHA everything is prepared against. Fetch heads with `git fetch origin +pull/<n>/head:refs/batch/<n>` (delete those refs when done). Per PR, record in the ledger: author, head and base SHA, files touched, checks, unresolved threads (existing ones too — `pr-wait` will not report them), Codex review state.

Rewriting and force-pushing the selected branches is authorized, with `--force-with-lease=<branch>:<recorded head SHA>`. Someone else's branch needs the user's OK first; a dependabot/renovate PR stops being managed by its bot once force-pushed, so ask it to rebase (`@dependabot rebase`) instead. If a PR already has a worktree (`git worktree list`) or a live `pr-wait` (its lock under `~/.local/state/pr-wait/`), another session may own it: confirm it is idle or ask, and never kill another watcher.

## 2. Triage

Dispatch read-only `explore` agents in parallel, one per PR or small group: has main already delivered it, did the code it changes move or vanish, does it compete with another selected PR? Draft a verdict per PR — **KEEP** (rebase and carry), **REWORK** (the idea stands, the code no longer fits) or **CLOSE** (superseded or obsolete) — with evidence. Present the verdict table for confirmation as one item, plus at most five genuine open questions, each with your recommendation. REWORK and CLOSE leave the batch only on the user's word and stay in the ledger as blocked; REWORK is follow-up work, not done here.

## 3. Interaction plan

For the KEEP set:

- **Against main:** `git merge-tree --write-tree --name-only <recorded main> refs/batch/<n>` (exit 1 = conflict, files listed).
- **Between PRs:** predict from overlapping changed files; the real pairwise result comes in step 4, once every head sits on the same main.
- **Semantic:** a real prerequisite is one PR using what another adds or changes; read the code for it. File overlap alone is not a dependency.

Default every PR to independent against main. Stack (plain base branches, never GitHub native stacks) only on a real prerequisite. Two independent PRs that conflict stay independent; whichever lands second needs a rebase afterwards. Order: prerequisites first, then PR number. A dependency cycle or two PRs implementing incompatible behavior goes back to the user.

Present the plan — ledger, verdicts, order, stack edges and the base changes they need (including un-stacking existing stacks), predicted conflicts — and wait for sign-off. Sign-off authorizes exactly the base changes listed.

## 4. Prepare locally

One worktree per PR (`.worktrees/batch-<n>`, unless the repo's AGENTS.md rules them out). Rebase onto the recorded main with `git -c rerere.enabled=true` so repeated resolutions replay, and inspect every replayed one. Stacked children go onto their prepared parent with `git rebase --onto <prepared parent> <old parent head> <child>`; a plain rebase would replay the parent's pre-resolution commits. The same applies whenever a parent is rewritten later. Compare `git range-diff` before and after: nothing intended may vanish, nothing already on main may come back. A conflict that reveals a product disagreement reopens triage for that PR.

With every head on the recorded main, check the overlapping pairs: `git merge-tree --write-tree --quiet <a> <b>`. A pair the plan didn't predict goes back to sign-off.

Build a local-only integration branch from the recorded main, merging every prepared PR in plan order. Resolve its conflicts there: each one is the rebase the later PR will need after the earlier lands, so record it per pair for the handoff. Run the repo's documented checks at the tip.

A PR whose resolution — its own rebase or an integration conflict — changed what it does goes through `super-review` as its calling workflow, with the PR's intent and the range-diff as plan and non-goals; a mechanical rebase does not.

## 5. Publish and babysit

Push once per PR, parents before children; on a lease failure, re-triage that PR rather than overwrite. Apply the signed-off base changes (`gh pr edit <child> --base <parent branch>`) and verify each.

Follow the `babysit` skill (as a subagent, read its `SKILL.md`), watching the whole batch with one `pr-wait <n1> <n2> …` — it exits on the first PR that needs action and spaces its polls for the batch size. Collect fixes and push them in waves, not per finding; a fix to a parent invalidates its children's checks. If main moves under the batch, refresh the ledger and decide whether the set still holds rather than rebasing in a loop.

After the last wave, rebuild the integration branch from the final heads and rerun its checks.

## 6. Handoff

Refetch and recheck every PR's head, base, checks, threads and merge state. Report a table — PR, verdict, head SHA, base (and for stacked children the parent's head SHA), CI, review outcome, blocker and what unblocks it — ready relative to the recorded main SHA, naming the heads the integration checks covered. Add the landing order and what each landing triggers: which PRs need a rebase afterwards, with the recorded resolution, and that each stacked child needs `babysit` once its parent lands. The rerere cache that holds those resolutions lives only on this machine.
