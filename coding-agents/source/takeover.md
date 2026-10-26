---
description: Use when finishing someone else's work — another person's PR or branch, or a stalled agent session's worktree — while preserving their credit.
mode: primary
permission:
  bash: allow
  edit: allow
  webfetch: allow
  task:
    "*": allow
---

<!-- Adapted from t3dotgg/tstack (MIT): skills/takeover -->

# Takeover

Finish the original goal and keep the original contributors' credit. Do not defend an implementation because someone already built it; the handoff is context, not proof.

## 1. Acquire

Resolve the source to actual code: PR head, branch tip, or worktree including uncommitted changes. Read the issue, PR body, review threads and the user's later corrections; for an agent session also its capture or plan (`docs/brainstorms/`, PR drafts). Before touching another session's worktree, confirm it is idle (no live process in it, e.g. `lsof +D`), or ask; copy uncommitted work into your continuation rather than committing in place.

## 2. Shape of the continuation

- Your own or explicitly handed-over PR: continue in place.
- Someone else's PR: a replacement branch in `.worktrees/<n>-takeover` from `origin/<base>` (unless the repo's AGENTS.md rules out worktrees), with their commits imported (`git cherry-pick` keeps authorship), your changes as separate commits, and a new PR that links the original. Honor an explicitly requested stacked or in-place continuation instead. Never push to or close their PR without authorization.

Keep git authorship and existing human co-author trailers; drop AI co-author trailers from imported agent-session commits. Credit original contributors in the PR body, and if the repo squash-merges, add `Co-authored-by:` lines there for the merger, using verified identities rather than guessed emails.

## 3. Finish

If the work is stale against its base, load `modernize` and run its steps 2–5 on the continuation; shipping stays with this skill. Otherwise plan the remaining work as in `ic`: what stands, what is reworked, change budget; wait for sign-off. Finish the same goal — simplify without dropping intended behavior, add nothing unrelated. Independently reproduce the original failure or exercise the intended workflow; state what stays unverified. Recheck the source before shipping: it may have moved while you worked.

Then take it through `ic`'s review wave, verification artifacts and `commit`, without its issue-assignment and worktree setup; open or update the PR per step 2, then load and follow `babysit`.

## Report

What you inherited (source, head, uncommitted work), what you changed and why, how you verified it, how credit was preserved, PR link, CI and review outcome, and any remaining decision.
