---
description: Deploy prep. Use when preparing, sanity-checking, or risk-assessing a deployment of the Kolai platform to any host of the infrastructure repo — figuring out what a deploy would actually ship, what changed since the last one, and what could break.
mode: primary
permission:
  bash: allow
  edit: allow
  webfetch: allow
---

# Deploy Prep

Assess what a deploy of the Kolai infrastructure repo would actually ship to a host and what could go wrong — BEFORE anyone runs ansible. The deliverable is a risk assessment plus concrete prep steps. Do not run the deploy itself unless explicitly asked.

## Facts that are easy to get wrong

- **Release scheme:** app repos tag releases `vYYYY-NNNNNN` (git) which publish image tag `YYYY-NNNNNN` on GHCR. Counters are independent per repo and reset yearly. Users say "2026-000012"; the git tag is `v2026-000012`. `git tag -l '2026-*'` finds nothing.
- **Hosts track `latest` by default** (`env_backend_tag`/`env_frontend_tag` in `ansible/roles/deploy/defaults/main.yml`, overridable per host). "Deploying to X" means "whatever `latest` resolves to at pull time" — a green CI run mid-deploy can flip it under you.
- **A git release tag does not guarantee a published image.** CI publish can fail after tagging. Always verify GHCR.
- **db-init is content-addressed** (tag = git tree sha of `services/db-init/`), published independently of backend releases. A sha-looking db-init tag is normal, not a mismatch.
- **A vault key existing does not mean the feature is active.** The chain is vault var → `roles/deploy/defaults/main.yml` mapping → `templates/env.j2` conditional → `.env` (all app services use `env_file: .env`). A `vault_*` key with no `env_*` mapping in defaults or host_vars renders nothing — changes to that provider are inert on that host.
- **The deploy copies compose + configs from the controller's worktree.** Uncommitted local changes to `docker-compose.yml`, templates, or host_vars WILL ship.

## Workflow

### 1. Pin down the delta

Ask the user (or use what they stated) for the currently-deployed versions. Then:

```bash
git -C backend-core fetch origin --tags -q && git -C frontend-react fetch origin --tags -q
git -C backend-core tag -l 'v2026*' | sort -V | tail -3      # incoming = newest
git -C frontend-react tag -l 'v2026*' | sort -V | tail -3
git -C backend-core log --oneline vOLD..vNEW
git -C frontend-react log --oneline vOLD..vNEW
git -C backend-core log --oneline vNEW..origin/main          # unreleased overhang
```

Commits on main past the newest tag = either CI-only pushes (no image) or a release stuck/in-flight — resolve which with the CI check in step 5.

### 2. Verify images exist and what `latest` points at

```bash
ORG=$(git -C backend-core remote get-url origin | sed -E 's#.*[:/]([^/]+)/[^/]+$#\1#')
gh api "orgs/$ORG/packages/container/backend-core/versions?per_page=8" \
  --jq '.[] | .metadata.container.tags | select(length>0) | @csv'
# same for frontend-react; expect "YYYY-NNNNNN","latest" on the newest
```

If `latest` ≠ the newest release tag, or the expected tag is missing: stop and flag it. Check the repo's CI runs to tell in-flight (wait, then re-verify GHCR) from failed publish (assess and deploy against the newest *published* tag pair instead, and flag the broken release separately).

### 3. Classify the backend delta

```bash
git -C backend-core diff --name-status vOLD..vNEW -- migrations/   # any migration?
git -C backend-core diff vOLD..vNEW -- .env.example                # new env vars?
```

- **Migrations:** read each one. Additive nullable columns = safe, rollback-tolerant. Column drops, type changes, data backfills, index builds on big tables = flag with expected impact.
- **New env vars:** for each, trace the wiring chain (see Facts). Vars with backend defaults need no infra change; required secrets need vault + defaults + env.j2 together (see AGENTS.md).
- **Provider-scoped changes:** determine which providers are live on the target host — `ansible/inventory/host_vars/<host>/main.yml` plus `cd ansible && ansible-vault view inventory/host_vars/<host>/vault.yml | grep -oE '^vault_[a-z_]+'` — and mark changes to inactive providers as inert. Flag dead vault keys you notice. Exception: if the delta makes a var required at startup (no backend default), an unwired key becomes a blocker.
- **Behavioral changes on active subsystems** (OCR, workers, startup/prewarm paths): note as post-deploy watch-items.

### 4. Classify the frontend delta + cross-repo pairing

Separate runtime commits from tests/lint/CI-only. For co-developed features (e.g. a backend capability + frontend gate), check both sides land in the shipped pair — name what's missing if one side lags a release.

### 5. CI health / `latest` race

```bash
gh run list --repo "$ORG/backend-core" --branch main --limit 5
gh run list --repo "$ORG/frontend-react" --branch main --limit 5
```

In-flight or red runs on main, or code commits past the newest tag → `latest` can change between assessment and pull. Recommend pinning `env_backend_tag`/`env_frontend_tag` in `ansible/inventory/host_vars/<host>/main.yml` for the deploy (and note pins must be bumped next time).

### 6. Controller worktree

`git status` in the infra repo. Uncommitted changes under `docker-compose.yml`, `ansible/` → they deploy; call them out. Then dry-run the render:

```bash
cd ansible && ansible-playbook playbooks/deploy.yml -l <host> --tags config --check
```

(Needs SSH reachability of the host and the vault password from `~/.vault_pass`; skip with a note if the host is unreachable.)

### 7. Report

Risk-ranked: **blockers** (missing image, unwired required secret, destructive migration), **watch-items** (behavior changes on active subsystems, first-startup effects), **safe** (tests/refactors, inert provider changes). End with the concrete prep list (pins, vault edits, config render) and the rollback note: the deploy retags the previous images `rollback-prev` on the host (`deploy_rollback_image_tag`).

## Red flags

- "The tag exists, so the image exists" — verify GHCR.
- "The vault has the key, so the provider is configured" — trace the env chain.
- "Main is green so `latest` is stable" — check for in-flight runs before pulling.
- Estimating risk from commit subjects alone — read migrations and `.env.example` diffs.
