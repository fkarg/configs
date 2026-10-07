# Peer review history

Approved design: add `--recent [N] [--all]` and `--show ID`, without `--last`.
Use atomic per-review JSON files under `${XDG_CACHE_HOME:-$HOME/.cache}/peer-review`.
Store the brief, UTC completion time, repository root (directory outside Git),
mode, and complete formatted response. Do not store supporting material.
Recent listings default to five entries in the current repository, newest first,
with IDs, answering model, brief and a short outcome. Show reproduces the original
stdout exactly and works across repositories. Retrieval never invokes a peer.
Cache failures warn on stderr while preserving the successful peer response.

Implementation (current master checkout; preserve unrelated edits):

- [x] Extend `coding-agents/test_peer_review.py` with CLI round-trip tests,
  repository filtering, limits, concurrent writes, error handling, and failures.
  Run `python3 -m unittest discover -s coding-agents -p test_peer_review.py`
  to confirm missing-feature failures before implementing.
- [x] Extend `scripts/peer-review` argument parsing, history retrieval, and
  final response persistence. Check `lsof scripts/peer-review` before editing;
  replace the script atomically, preserving executable permissions.
- [x] Document commands and cache behavior in `coding-agents/README.md` and
  recovery guidance in `coding-agents/configs/shared/AGENTS.md`.
- [x] Run launcher tests and `sh -n scripts/peer-review`; get an independent
  diff review via `peer-review --stdin --mode diff-review` with only task files.
  Resolve actionable findings, rerun relevant checks, and commit touched files.

Review dispositions:

- Claude Opus 5.5: found a unique defect (corrupt JSON blocked every listing).
  Reproduced with a regression test, then fixed by warning/skipping bad files.
  Worktree scoping stays checkout-local, now explicitly documented. Default-mode
  acceptance and optional-count ordering had no decision impact. Consolidated
  the `--all` guard. Kept Python directory resolution: unlike the proposed shell
  simplification it works without Git, tested through the CLI. Kept the standard
  private temporary-file helper and full help/README explanations.
- Fresh-context reviewer: found a unique defect (cleanup errors could discard a
  successful answer). Reproduced read-only filesystem publication plus cleanup
  failures in the CLI regression test, then fixed by suppressing cleanup errors.
- Verification: launcher suite passes 63 tests. Mutation checks confirmed that
  repository filtering and exact full-response replay regressions fail tests.
  Retrieved the actual Claude review with `--recent` and `--show`; replay exactly
  matched the saved stdout. Fresh-context follow-up review found no new defects.
