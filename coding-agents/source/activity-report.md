---
description: Activity report. Use when summarizing what you did over a stated timeframe across the Epistree repos (infrastructure, frontend-react, backend-core) — issues, PRs, commits, reviews given, and in-flight local work — to prepare for a recurring team sync, standup or status update, or to answer "what have I been working on".
mode: primary
permission:
  bash: allow
  edit: deny
  webfetch: allow
---

# Activity Report

Report what the user did across `~/Coding/{infrastructure,frontend-react,backend-core}` in a stated timeframe, and turn it into a handful of bullets they can actually say out loud in a team sync. Read-only against everything that matters: never commit, push, or comment on an issue or PR, and never write inside the repos. Scratch files under `/tmp` are fine; the report itself goes to chat.

## Input

The timeframe comes from the user ("last two weeks", "since Monday", "2026-07-20..2026-08-03"). Resolve it to an absolute `SINCE` (plus `UNTIL` if bounded) **before anything else** and state it at the top of the report — every query below depends on it.

```bash
SINCE=$(date -v-14d +%F)          # macOS; GNU coreutils: date -d '14 days ago' +%F
```

If no timeframe was given, ask. Do not guess one.

## Facts that are easy to get wrong

- **All three repos are in the `Epistree` org; the GitHub account is `fkarg`.** `Epistree/infrastructure`, `Epistree/frontend-react`, `Epistree/backend-core`.
- **Filtering commits by author badly undercounts the work.** A large share of commits in these repos are authored by `198982749+Copilot@users.noreply.github.com`, `noreply@anthropic.com`, or `github-actions[bot]` — inside PRs the user opened, drove and merged. That is his work. **The PR is the unit of work; commits are supporting detail.**
- **His own commits carry three identities**: `f.karg10@gmail.com`, `9039899+fkarg@users.noreply.github.com`, `hello@kolai.eu`. `git log --author=` is repeatable and ORs — pass all three or you will silently drop a repo's worth of history.
- **`gh search --updated` means "touched in the window", not "done in the window".** A colleague deleting merged head branches bumps a dozen months-old PRs into the results; board moves and cross-references from new PRs drag the whole issue backlog in. Read `createdAt` / `closedAt` / `mergedAt` on every hit and split it into *created in window*, *closed in window*, *created before and finished now*, and *backlog churn — drop it*.
- **Reviews are invisible to every author-based query — and `--reviewed-by` lies about dates.** It filters on the PR's `updated`, not the review's. A review submitted two months ago surfaces as a hit. Confirm each one before counting it:
  ```bash
  gh api repos/Epistree/$R/pulls/$N/reviews --jq '.[] | select(.user.login=="fkarg") | "\(.submitted_at) \(.state)"'
  ```
  Zero reviews in a window is a normal result — report it as zero rather than passing off stale hits as review activity.
- **Local state does not sync between his three machines.** `.worktrees/` and unpushed branches are this machine's view only. Label them as such — finding nothing here is *not* evidence that no work is in flight elsewhere.
- **The repos deliver differently, and the PR pass alone will lie about `infrastructure`.** `backend-core` and `frontend-react` go through PRs. `infrastructure` ships mostly **direct to `main`** — whole weeks there have zero merged PRs and 25+ pushed commits. An empty PR list for infrastructure is not an idle week; group its `main` commits by theme and treat them as the unit of work.
- **For the PR repos, merged PRs land on `main` with the merge**, so `git log origin/main --since` re-lists what the PR pass already found. There, use it to catch direct pushes and confirm merges, not as a primary source.
- **Use commit date, not author date** (`%cd`, `--since` already filters on commit date). Commits authored days earlier land later — "when did it ship" is the commit date, and the gap is itself worth mentioning when it is large.

## Workflow

### 1. Fan out — one subagent per repo, in parallel

Three repos, no shared state: dispatch all three in a single message (any read-capable general subagent — `explore` / `general-purpose`). Give each one the repo name, the absolute window, the three author identities, and the query set below. Ask for terse structured findings, not prose, and tell it to report what it found without editorialising or ranking.

```bash
R=backend-core; SINCE=<absolute date>

# PRs he drove — merged, open, closed
gh search prs --repo Epistree/$R --author fkarg --updated ">=$SINCE" --limit 200 \
  --json number,title,state,url,createdAt,updatedAt,closedAt

# Issues he opened or closed
gh search issues --repo Epistree/$R --author fkarg --updated ">=$SINCE" --limit 200 \
  --json number,title,state,url,createdAt,closedAt
# Issues he was pulled into but did not open (assigned, commented, referenced)
gh search issues --repo Epistree/$R --involves fkarg --updated ">=$SINCE" --limit 200 \
  --json number,title,state,url,author

# Reviews he gave on other people's PRs — dates need confirming, see Facts
gh search prs --repo Epistree/$R --reviewed-by fkarg --updated ">=$SINCE" --limit 100 \
  --json number,title,author,state,url

# What actually landed on main (the primary source for infrastructure)
git -C ~/Coding/$R fetch origin -q
git -C ~/Coding/$R log origin/main --since="$SINCE" --format='%h %cd %an %s' --date=short
```

**Count the results against the limit before using them.** `gh search` truncates silently: on the first real run a `--limit 60` returned exactly 60 of 70 PRs and the report simply lost ten. If a result count equals the limit, it is a truncated page — raise the limit or split the window, and say which you did.

For each of his merged PRs, produce one line of **what it changed for the product**, not the title reworded — `gh pr view N --repo Epistree/$R --json title,body,files` or the commit list over the merge. Enough to explain the effect; skip file-by-file detail.

To tell genuine direct-to-main pushes from commits that arrived via a merge, ask GitHub rather than eyeballing subjects:

```bash
gh api repos/Epistree/$R/commits/$SHA/pulls --jq 'length'   # 0 => direct push
```

### 2. Local, un-synced work (this machine only)

```bash
git -C ~/Coding/$R worktree list
git -C ~/Coding/$R status --short                     # dirty primary checkout
for w in ~/Coding/$R/.worktrees/*/; do
  echo "== $w"; git -C "$w" status --short
  git -C "$w" log --oneline '@{u}..' 2>/dev/null || git -C "$w" log --oneline origin/main..
done
git -C ~/Coding/$R branch -vv | grep -v '\[origin/'   # local branches with no upstream
```

Per branch, state: does it have a PR, does it have unpushed commits, are there uncommitted changes, and is it stale (no commit inside the window)? Stale worktrees are worth flagging as cleanup candidates.

Traps, all three hit on the first real run:

- `.worktrees/` contains **directories that are not worktrees at all** — leftovers whose registration is gone. `git -C` there silently falls through to the primary checkout, so they report the primary repo's status as if it were theirs. Filter: keep a directory only if `git -C "$w" rev-parse --show-toplevel` equals `$w`.
- It can also hold worktrees **belonging to a different repo**, which never appear in this repo's `git worktree list`. Glob the directory as well as reading the list.
- `@{u}..` fails with `fatal: ambiguous argument` on any branch whose upstream was deleted after its PR merged. That is the normal state for finished work, not an error worth reporting — fall back to `origin/main..`.

Also separate "untracked scratch docs and log dumps sitting in the checkout" from "uncommitted changes to tracked files". Both repos' primary checkouts carry long-lived local notes that are not work-in-progress.

### 3. Agent sessions running right now

Work in progress that has not reached git at all:

```bash
pgrep -alf 'claude|codex|opencode' | grep -v ' app-server' | while read -r pid cmd; do
  cwd=$(lsof -a -d cwd -p "$pid" -Fn 2>/dev/null | sed -n 's/^n//p')
  case "$cwd" in
    */Coding/infrastructure*|*/Coding/frontend-react*|*/Coding/backend-core*) echo "$pid  $cwd  $cmd";;
  esac
done
```

The VS Code Codex extension keeps persistent `app-server` processes alive that are not sessions — filtered above. For sessions that ended recently, `ls -dt ~/.claude/projects/*Coding-{infrastructure,frontend-react,backend-core}*` ranks those repos' session dirs by last activity.

**Discount this run itself.** The session generating the report — and every subagent shell it spawns — matches the same pattern and will otherwise be reported as work in progress. Drop any PID whose command line is a `git`/`gh` query, and any session whose cwd is the one this report is running from.

### 4. Synthesize in the main thread

Merge the three reports. Deduplicate: an issue, its PR, and its commits are **one** item of work — report it once, at PR granularity, with the issue as context. Group cross-repo work that belongs together (a backend capability plus its frontend gate is one story, not two). Order by what a colleague would care about, not by repo or timestamp.

**Expect volume.** A fortnight can be ~30 merged PRs in `backend-core` alone. Enumerating them is not a report — collapse into 4–8 themes (e.g. "search quality, now benchmark-backed", "tenant-isolation fixes", "CI cost"), and inside each name only the items a colleague would ask about. Two things always survive summarisation and must be called out individually: **security/isolation fixes** and **incidents that were fixed** (a deploy that was broken, a leak that was closed) — those are the sentences colleagues actually need.

## Report format

Lead with **Window** (absolute dates) and **Scope** (the three repos, this machine).

- **Shipped** — merged PRs, grouped by outcome, each one line: what it does now that it did not before. Link `Epistree/repo#N`.
- **In flight** — open PRs and local branches, each with its actual state: awaiting review, blocked on X, WIP.
- **Unblocked others** — reviews given, issues triaged or answered for colleagues.
- **Local-only on this machine** — dirty worktrees, unpushed branches, running agent sessions, stale worktrees. Prefix with the caveat that this does not cover his other machines.
- **For the sync** — 4–6 bullets in spoken register. Outcome, not mechanism; no PR numbers unless a colleague needs to look one up. Close with blockers/asks and what he is picking up next.

## Red flags

- Filtering commits by author and calling that the week's work — the bot-authored commits inside his PRs are his.
- Reading `--updated` as "worked on it" — check `merged-at` / `closed` before claiming something shipped.
- Reporting PR titles verbatim as the sync bullets. Colleagues want the effect, not the changelog.
- Presenting this machine's worktree state as the complete picture of in-flight work.
- Writing, committing, or commenting anything. This skill only reads.
