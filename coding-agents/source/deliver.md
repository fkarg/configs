---
description: Use when a reviewed change is ready to become a pushed PR — the delivery step of ic, modernize and takeover: reading guide, verification walkthrough, commit, push, open or update the PR, then babysit.
mode: skill
---

# Deliver

Turn a reviewed change into a pushed PR with the evidence a reviewer needs, then babysit it. The caller supplies: worktree, base, branch, the `super-review` result (map, findings synthesis, production report), PR identity (open a new one, or update `#n` and the head SHA observed before any history rewrite), issue linking (`Closes #n`, `Related to #n` or none), credit (a PR-body section and `Co-authored-by:` trailers for the commit), and any sections its PR body leads with.

## 1. Artifacts

- **Reading guide:** rank judgment-heavy hunks to read closely and why; identify mechanical/test-pinned parts safe to skim.
- **Verification walkthrough:** run the final code on the documented local stack. Record repeatable setup and steps, expected and observed results, reaching the required user outcomes and an edge/negative case. Backend: commands and relevant output. Frontend: captioned screenshots of meaningful states using synthetic data; upload to the PR, never commit them. If upload fails, keep local paths and disclose it. Paired frontend/backend PRs share or link the sequence and name the counterpart head tested. Mark unrun checks with reasons; failed expected outcomes must be fixed. If there is no runnable surface, say so.

Any fix since the review — the caller's or one made here — changes the evidence: rerun the affected reviewers, update the map, and rerun `production-readiness` on the final diff. Continue to shipping unless a red finding or budget expansion needs the signer.

## 2. Ship

Stage exactly the final intended files, then delegate the commit to `commit`, using the repo's format, the caller's issue linking and credit trailers. Then:

- **New PR:** `git push -u origin HEAD`; open it against `<base>`.
- **Existing PR:** after a history rewrite push with `--force-with-lease=<branch>:<observed head SHA>` (on a lease failure, fetch and reassess), otherwise a plain push; then update its body.

PR body: the caller's leading sections, then the architectural map, reading guide, walkthrough with screenshots, review synthesis and production report.

Then load the `babysit` skill (as a subagent, read its `SKILL.md` from your harness's skills directory) and follow it until the PR is merge-ready. Return the PR link, head SHA, CI and review outcome, and walkthrough results with unrun steps to the caller.
