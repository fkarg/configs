---
description: Use when a pushed PR needs watching through CI, review bots and base-branch drift until it is merge-ready — after ic/modernize/takeover push, or when asked to babysit, watch or monitor a PR.
mode: skill
---

<!-- Adapted from t3dotgg/tstack (MIT): skills/babysit-pr -->

# Babysit

Own your PRs from push to merge-ready. Only the thread that owns a PR babysits it; a delegated reviewer never does.

## Watching

Use `pr-wait <pr>... [--repo owner/name] [--until ready|green|any-change]`; never write your own polling or `sleep` loop, and never run two watchers on one PR (it refuses). Several PRs you own go into one `pr-wait`, which exits on the first that needs action. It prints one line per event — failed check, new comment/thread/reply, review bot result, base commits touching this PR's files, BEHIND/DIRTY, merged/closed — and exits 0 when the condition is met, 1 when it needs action, 2 on bad input or an existing watcher. `ready` (default) is green checks, no unresolved threads, not BEHIND, and Codex's opening review finished (it gives up on a stuck 👀 after 20 minutes and says so).

- **Claude Code main thread:** run it with `run_in_background`; you are re-invoked when it exits. With a line-streaming monitor tool, use that instead.
- **Codex, or as a subagent** (nothing re-invokes you after your turn ends): run it in the foreground with a long timeout (an hour) and restart it on timeout.

Its first run on a PR records existing state silently, so handle the checks, threads and reviews already there before starting it. Restart it after every push, after handling an exit 1, and after a resume; it remembers what it reported for six hours. When an event needs no action, end the turn without a message, and never post "still waiting".

`gh pr view/checks/create` use GraphQL; if that limit is spent, read via REST (`gh api repos/<o>/<r>/pulls/<n>`, `.../commits/<sha>/check-runs`).

## Findings

Act only on checks and comments newer than the latest push, and verify every bot finding against the source before changing code. Codex reviews only when the PR opens, with findings or a 👍; don't post `@codex review` for later heads unless the user asked. If expected automated feedback never arrives, report that instead of waiting.

Fix real bugs in the intended case; decline the rest in a thread reply with the reason, and list them as follow-ups in the handoff. Replies lead with the conclusion and cite `file:line`, a check or output. After the reply posts, resolve bot threads and threads your fix addressed; leave a declined human thread open for that reviewer.

A fix changes the evidence: rerun the affected checks and your own reviewers, and update PR-body artifacts (map, walkthrough) whose claims it changed.

## Base and handoff

Rebase when the PR goes DIRTY, base commits touch its files, or it is BEHIND and the repo requires up-to-date branches; otherwise BEHIND needs nothing, so watch it with `--until green`, as you do when the only open threads are declined ones awaiting a human. Push a rebase with `--force-with-lease=<branch>:<head sha observed before the rebase>`, and on a lease failure fetch and reassess. When the PR it was stacked on has been squash- or rebase-merged, a plain rebase replays the parent's commits and conflicts with their squashed copy on main: retarget to main if GitHub hasn't, take the parent's last head from `gh pr view <parent> --json headRefOid` (confirm with `git merge-base --is-ancestor <sha> <branch>`, else find the parent commit the branch actually forked from), then `git rebase --onto origin/<main> <that sha> <branch>`. If an overlapping PR makes this one obsolete, stop and ask before closing it.

Before calling the PR ready, `git fetch` and recheck head, checks, threads and merge state. Never merge while BEHIND/DIRTY or with `--admin`. Hand off: PR link, head SHA, CI and review outcome, declined findings with reasons, and what remains.
