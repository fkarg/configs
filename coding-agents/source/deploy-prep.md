---
description: Use when preparing, sanity-checking, or risk-assessing a deployment of the Kolai platform to a host managed by the infrastructure repo.
mode: primary
permission:
  bash: allow
  edit: allow
  webfetch: allow
  task:
    "*": allow
---

# Deploy Prep

Assess what a deploy of the Kolai infrastructure repo would actually ship to a host and what could go wrong — BEFORE anyone runs ansible. The deliverable is a risk assessment plus concrete prep steps. Do not run the deploy itself unless explicitly asked.

You are the orchestrator. Fan out independent, read-only exploration and
fact-finding to subagents: for production deploy prep, cover release/CI state,
backend delta, frontend delta, open infrastructure issues, and
controller/config state. For narrower requests, use the applicable subset.
Parallelize investigations that do not depend on each other. Give each agent a
bounded question and the relevant repo path; do not delegate edits or the final
judgment. You own synthesis, user decisions, and any requested fixes — and you
deliver the final report only after every delegated analysis has returned, or
with the missing ones explicitly named as unverified.

## Shared model

**Read `docs/release-flow.md` in the infrastructure repo first.** Tag
identities, the candidate/promoted/published distinction, verification
recipes, and the delta-classification method live there, shared with
release-prep. `scripts/release.sh`, the app repos' workflow files, and
`AGENTS.md` override it. Paste the relevant facts into subagent prompts
instead of letting each agent rediscover them.

Deploy-specific facts that are easy to get wrong:

- **The deploy exports tracked compose + configs from controller `HEAD`.**
  Inspect the current deploy role before deciding whether any uncommitted file
  ships. Local role/task edits can still change what Ansible executes even when
  the delivered archive is based on `HEAD`.
- **Hosts track `latest` by default** — "deploying to X" means "whatever
  `latest` resolves to at pull time", and a deploy-branch publish mid-deploy
  can flip it under you (details in the doc).

## Workflow

### 1. Establish the deployment boundary

Record the target host, its currently deployed backend/frontend versions, and
the timestamp of the last deployment attempt. Prefer observed host/image state
and deploy notifications/logs over memory. If the attempt timestamp cannot be
established, ask for it: it is the minimum issue-review cutoff, not an optional
30-day window.

Fetch app refs and determine separately (recipes in the doc): `origin/deploy`
and the exact candidate + deploy tags pointing at it; the newest candidate on
`origin/main`; whether a newer candidate is intended to be released before
this deploy; and the deployed-to-target delta. Do not silently equate newest
candidate, promoted release, `latest`, and currently running image. Commits
and candidate tags after `origin/deploy` are unreleased overhang unless the
user explicitly intends to run `scripts/release.sh` first.

### 2. Verify promotion, CI, and images

For each app, locate the deploy-branch workflow run by the exact promoted or
candidate commit SHA and verify the intended image tags exist on GHCR with
`latest` on the same digest (recipes in the doc). If promotion is in flight,
wait and recheck. If it failed, stop: rerunning Ansible does not publish the
image. Never move `deploy`, rerun CI, or run `scripts/release.sh` without
explicit authorization.

### 3. Classify the backend delta

Classify deployed→promoted per the doc's method (migrations, env-var wiring,
provider-scoped inertness — determine which providers are live on the target
host from its host_vars and vault, and flag dead vault keys you notice).
Additionally, deploy-specific:

- **Behavioral changes on active subsystems** (OCR, workers, startup/prewarm
  paths): note as post-deploy watch-items.
- **Rollback tolerance:** data the new version moves or backfills that the
  currently-running image cannot read makes rollback lossy — say so.

### 4. Classify the frontend delta + cross-repo pairing

Separate runtime commits from tests/lint/CI-only. For co-developed features (e.g. a backend capability + frontend gate), check both sides land in the shipped pair — name what's missing if one side lags a release.

### 5. Review open infrastructure issues

This review is for the infrastructure repo only. Do not search backend or
frontend issues.

List metadata for **all open issues**. Fully read every still-open issue created
at or after the last deployment-attempt timestamp; this is a hard minimum, not
a relevance-filtered sample. Then inspect older open-issue metadata and fully
read any issue plausibly connected to the target host, shipped delta, release,
deployment, config/secrets, migrations/data work, monitoring, rollback, or a
known production failure. Labels are hints only: this repo's labeling is not
consistent enough to be a gate.

```bash
gh repo view --json nameWithOwner,url
gh issue list --state open --limit 1000 \
  --json number,title,createdAt,updatedAt,labels,url
gh issue view <number> --comments
```

Use full timestamps from the JSON rather than GitHub's day-granularity search
when the attempt time matters. Classify fully read issues as:

- **blocker** — deploying before resolution is unsafe or impossible;
- **required prep** — concrete work must happen before/during the deploy;
- **watch-item** — deploy can proceed with an explicit observation/check;
- **not applicable** — say why it does not affect this host or shipped delta.

Link every blocker, prep item, and watch-item in the report. Summarize the
not-applicable set compactly so the user can see that all post-attempt open
issues were considered. If `gh` authentication/API access fails, retry after
checking `gh auth status`; if still unavailable, mark issue review unverified
and do not claim readiness.

### 6. Controller worktree

Inspect `git status`, `HEAD`, the deploy role's staging/export logic, and changes
since the controller commit used for the last attempt. Distinguish:

- tracked content exported from `HEAD`;
- local role/playbook edits Ansible will execute;
- dirty submodule state, which does not itself change prebuilt app images; and
- unrelated untracked operational files.

Then dry-run the render:

```bash
cd ansible && ansible-playbook playbooks/deploy.yml -l <host> --tags config --check
```

(Needs SSH reachability of the host and the vault password from `~/.vault_pass`; skip with a note if the host is unreachable.)

### 7. Report

Risk-ranked: **blockers** (missing image, failed promotion, unwired required
secret, destructive migration, blocking issue), **required prep**,
**watch-items**, and **safe/not applicable**. Include the release pair and
evidence, issue-review cutoff and coverage, controller delta, concrete prep
steps, and unresolved facts. End with the rollback behavior verified from the
current deploy role; do not rely on a stale generic rollback claim.

## Red flags

- "The tag exists, so the image exists" — verify GHCR.
- "The newest candidate tag is the incoming image" — check `origin/deploy`,
  deploy-branch CI, and the intended release action.
- "The vault has the key, so the provider is configured" — trace the env chain.
- "Main activity can move `latest`" — only deploy-branch publication does.
- "No matching label means the issue is irrelevant" — read all post-attempt
  open issues and broaden into older plausible issues.
- Estimating risk from commit subjects alone — read migrations and `.env.example` diffs.
