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

Assess what a deploy of the Kolai infrastructure repo would actually ship to a
host and what could go wrong — BEFORE anyone runs ansible. The deliverable is a
risk assessment plus concrete prep steps. Do not run the deploy itself unless
explicitly asked.

You are the orchestrator. Fan out read-only fact-finding to subagents —
release/CI state, the app delta, open infrastructure issues, release cards for
the incoming interval, controller/config state — and parallelize what is
independent. Give each a bounded question, the repo path, and the shared-model
facts it would otherwise rediscover. Never delegate edits or the final judgment:
you own synthesis, user decisions, and any requested fixes. Report only after
every delegated analysis has returned, or name the missing ones as unverified.

## Shared model

**Read `docs/release-flow.md` in the infrastructure repo first.** Tag
identities, the candidate/promoted/published distinction, verification recipes,
delta classification, and release-card conventions live there, shared with
release-prep. This skill states what is deploy-specific and does not restate the
doc. `scripts/release.py`, the app repos' workflow files, and `AGENTS.md`
override it. Paste the relevant facts into subagent prompts.

The one fact the doc does not carry: the deploy ships `git archive HEAD` of the
controller, but local role/task edits still change what Ansible *executes*. So
inspect the role — "it isn't committed, so it can't ship" is wrong for the role
itself.

## Workflow

### 1. Deployment boundary

Record the target host, its running backend/frontend versions, and the timestamp
of the last deployment attempt — observed host/image state and deploy logs over
memory. If that timestamp cannot be established, ask for it: it is the
issue-review cutoff, not an optional 30-day window.

Then, per the doc's recipes, resolve each of these separately (the doc's "What
proves what" is why they are not interchangeable): `origin/deploy` and the exact
tags on it; the newest candidate on `origin/main`; whether a release is intended
before this deploy; and the deployed→target delta. Overhang past `origin/deploy`
does not ship unless the user intends to run `release.py` first.

### 2. Promotion, CI, images

Per app: locate the deploy-branch run by exact commit SHA, and verify the
intended image tags exist on GHCR with `latest` on the same digest. In flight →
wait and recheck. Failed → stop; rerunning Ansible publishes nothing. Never move
`deploy`, rerun CI, or run `scripts/release.py` without explicit authorization.

### 3. Delta gate — the doc's queries, scoped to this host

Run the doc's delta classification over deployed→promoted in **both** repos.

Deploy-specific scoping, plus the queries the doc does not carry:

1. **Migrations** — read each, as the doc says.
2. **Env / settings** — diff `.env.example` and the settings class, then walk
   the doc's wiring chain. A var an app repo consumes that this repo never
   renders in `roles/deploy/templates/env.j2` is a blocker with both app repos
   green: consumer and fix live in different repos, so no PR body shows it.
3. **Feature flags** — run the doc's flag query against the host's
   `env_flipt_environment` directory in `Epistree/feature-flags`.
4. **API surface** — as the doc says; name any half-landed pair.
5. **Live subsystems** — read the host's host_vars and vault key names (names
   only) to decide which providers are live; changes to inactive ones are inert
   unless the delta makes their var required at startup. Cover parsing,
   encoding, MIME and validation changes on user-facing input paths, where
   locale assumptions break per-customer, and note startup/prewarm, worker and
   OCR changes as post-deploy watch-items. Flag dead vault keys.
6. **Commit subjects, last** — `git log --oneline vOLD..vNEW` as a tripwire
   only: follow up on a subject that hits 1–5 and was missed, narrate nothing
   else.

### 4. Open infrastructure issues

Infrastructure repo only — do not search the app repos. This step covers
**unresolved** work; what ships comes from step 3 and the card comment, not from
an issue sweep.

Read every open issue's title — that part is not sampled. Full-read (issue plus
comments) any open issue, of any age, touching the target host, config/secrets,
migrations or data work, monitoring, rollback, or a known production failure —
plus anything ambiguous. Floor: no issue created at or after the last attempt is
dismissed without its title being read, and the report names each one so
dismissed. A title can hide a blocker in the body, so skip a full read only on
an unambiguously off-topic title (dependency bumps, docs, another host); when in
doubt, read. Labels gate nothing here — this repo's labeling is not consistent
enough to filter on.

```bash
gh issue list --state open --limit 1000 \
  --json number,title,createdAt,updatedAt,labels,url
gh issue view <number> --comments
```

Use the JSON timestamps, not GitHub's day-granular search. Classify fully read
issues as **blocker** (deploying first is unsafe), **required prep**,
**watch-item**, or **not applicable** (say why), and link every blocker, prep
item and watch-item. If `gh` fails, retry after `gh auth status`; if still
unavailable, mark the issue review unverified and do not claim readiness.

### 5. Release cards

Read every card in the host's deployed→target interval, open or closed (doc:
"Consuming cards"). Union the applicable notes, filtered by this host's
providers, into prep steps and watch-items — claims to verify against step 3,
never a substitute for running it: a card records what an author knew to write
down, while step 3 catches the cross-boundary consequences no PR author could
self-report. Each card also carries `release.py`'s cut comment, whose mechanical
closed-issue list indexes the interval but is not a record of it — it is keyed
on closing time, not shipping time, and lists issues, not PRs. Append
post-deploy discoveries as dated comments.

### 6. Controller state and infra deploy notes

Inspect `git status`, `HEAD`, and the deploy role's staging/export logic, and
separate: tracked content exported from `HEAD`; local role/playbook edits
Ansible will execute; dirty submodules (no effect on prebuilt app images); and
unrelated untracked files.

Read infra PRs' `## Deploy impact` sections directly over this host's last
successfully applied controller revision → target (doc: "Infrastructure PRs
never pass through a cut"), scan that range's commit subjects for direct pushes,
and diff only what plausibly touches this host. Do not manufacture prep steps
from `None`/boilerplate sections or copied release-card text.

Then dry-run the render:

```bash
cd ansible && ansible-playbook playbooks/deploy.yml -l <host> --tags config --check
```

(Needs SSH reachability and the vault password from `~/.vault_pass`; skip with a
note if the host is unreachable.)

### 7. Cross-model gate — after the facts, before the verdict

```bash
peer-review --mode premise --cd <infra-repo> "Deploying <release pair> to <host>. \
Established: <migrations, image/tag evidence, secret wiring, controller delta, open blocking issues>. \
Rollback behavior read from the current deploy role: <summary>. \
Name the failure mode this evidence does not rule out."
```

Aim it at what a facts-only reader would still worry about: an overlooked
rollback path, version-identity mismatch, migration/image cutover ordering, a
provider configured but not active. Do **not** hand it your go/no-go verdict —
it reasons from the evidence, it does not rate your conclusion. Report its
answer as its own line naming the model; if `attempted_falsifications` is empty,
say the peer left its conclusion untested rather than counting it as a pass.

### 8. Report

Risk-ranked: **blockers** (missing image, failed promotion, unwired required
secret, destructive migration, blocking issue), **required prep**,
**watch-items**, **safe/not applicable**. Include the release pair and its
evidence, the issue-review cutoff and coverage, the controller delta, prep
steps, and unresolved facts. State which step-3 queries ran and what each
returned, "none" included — the delta report is short, so its coverage has to be
visible. End with the rollback behavior verified from the current deploy role,
never a stale generic claim.

## Red flags

- "The tag exists, so the image exists" — verify GHCR.
- "The newest candidate tag is the incoming image" — check `origin/deploy`,
  deploy-branch CI, and the intended release action.
- "The vault has the key, so the provider is configured" — trace the env chain.
- "Main activity can move `latest`" — only deploy-branch publication does.
- "No matching label means the issue is irrelevant" — labels gate nothing.
- "The title sounded unrelated" as the only reason a post-attempt issue went
  unread — name those issues so the user can see the call.
- "The card lists the closed issues, so the issue review is covered" — the card
  indexes what is *finished*; step 4 is for what is still open.
- Estimating risk from commit subjects — subjects are the tripwire; the
  migration, env, flag and API diffs are the gate.
- "The cards say nothing / it all looks like UI work, so I stopped early" — step
  3 is queries to run, not a judgment to make up front, and a quiet card is
  exactly when the flag and env queries pay.
- "The flag key exists in the code, so it is live here" — check this host's own
  environment directory, and whether the delta newly *requires* a variant it
  does not serve.
- "The last attempt covered those infra commits" — a failed or partial apply
  advances nothing.
