# Evicted agent knowledge → Epistree repos' AGENTS.md

The 2026-07 slimming of `coding-agents/source/` removed repo-specific facts from
the generic agents (per the policy in `configs/shared/AGENTS.md`: repo knowledge
lives in that repo's AGENTS.md). The agents now say "check the repo's AGENTS.md"
— which only works once these facts actually live there. Paste, adapt, then
delete this file.

## backend-core

- Static checks: `./scripts/check.sh`; tests: `uv run pytest -n auto <path>`.
- Module layout: `schemas.py` / `services.py` / `models.py` / `views.py` /
  `config.py`; thin views, typed async services.
- Services are thin delegation layers and are not unit-tested separately —
  coverage comes from behavior tests in `tests/*/test_services.py`.
- **Deploy model**: migrations run synchronously at startup (`alembic upgrade
  head` in `run_migrations()`); the app blocks until they complete. A brief
  restart is normal; a long-running migration (index build without
  `CONCURRENTLY`, large backfill) means extended downtime — flag it.
- The frontend client is auto-generated from `operation_id`s — removing or
  renaming one requires frontend client regeneration.
- Feature flags via OpenFeature; risky behavior changes should ship with a kill
  switch.

## frontend-react

- Checks: `pnpm tc`, `pnpm build`, plus the narrowest relevant browser tests.
- Data flow: hooks → services → generated-client boundary; thin route modules;
  components never call generated clients directly.
- i18n is mandatory for user-facing strings.

## all Epistree repos (backend-core, frontend-react, infrastructure)

- Issues auto-add to the Development project board at status **Backlog**; no
  manual board step after `gh issue create`. Flow: Backlog → Plan → Ready → In
  Progress → Reviewing → Done, plus **Stuck** when blocked.
- Deployment/infra-layer follow-ups (provisioning, scaling, managed services,
  secrets, quotas, rollout ordering) are filed on the `infrastructure` repo;
  application follow-ups stay in the repo they belong to.
