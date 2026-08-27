# Release-Aligned Infrastructure Context Design

## Goal

Make regular deploy preparation inspect infrastructure commit messages made
between the previously released application revision and the candidate being
prepared, so relevant operational context is not lost in generic PR deploy
notes.

## Scope

The canonical `deploy-prep` agent prompt will gain a release-aligned
infrastructure context scan. The interval is bounded by the commit dates of
the outgoing app release and incoming candidate; it includes commits that
landed through PRs as well as direct pushes.

The scan will group and summarize commit subjects. A subject that plausibly
affects the target host or release is investigated through its diff. Generic
or unrelated messages remain context only and do not create prep work.

## Boundaries

The existing controller inspection remains responsible for determining what
configuration can actually ship from controller `HEAD`. This release-aligned
scan is not a substitute for that inspection and does not use PR `Deploy
impact` sections or copied release-card text as a source of action items.

## Reporting

The deploy-prep report will include a compact infrastructure-context summary
alongside the release pair. Only evidence from a relevant commit/diff may add
a blocker, required-prep item, or watch-item.

## Validation

Render the canonical source with `python3 coding-agents/build.py` and inspect
the generated Codex and Claude skill variants for the new instructions.
