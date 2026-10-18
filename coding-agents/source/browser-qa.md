---
description: "Use when preparing or running browser QA for a deployed PR stack, testing what frontend/backend PRs promise, or retesting a new wave with evidence and separate FE/BE readiness tables."
mode: skill
---

# Browser QA

Test observable product behavior and report evidence for the user's further testing and review. This is purely testing and QA: do not implement fixes, deploy, approve PRs, merge, close PRs, or change their draft state. Recommendations never perform those actions. If asked to do development or release work, treat it as a separate task outside this skill.

## Scope and provenance

Read the relevant repository instructions and README. Resolve the target environment, repositories, selected PR wave, accounts and allowed test actions from the request and existing session. For Kolai, the usual repositories are `Epistree/frontend-react` and `Epistree/backend-core`; confirm their current location rather than assuming a particular machine path or browser hostname. Kolai's local-stack QA notes (targets, role-to-profile mapping, smoke baseline) are in the infrastructure repository's `docs/qa-browser.md`.

Use `gh` for PR descriptions, linked requirements, relevant diffs, current heads, dependencies, primary CI and conflict status. Run authenticated `gh` on the host where required for keyring access. Record capture time, exact head and check identity; unrelated green checks, skipped/cancelled checks and old successful runs are not primary validation of a prospective merge. Preserve local checkouts and unrelated changes.

Record deployed FE/BE commits or image identifiers, environment class (production/staging/preview/unknown), timestamp/timezone, displayed version, relevant flags, capabilities and account roles in the deployment manifest. Unknown values stay unknown. A version label or open PR list does not prove inclusion. If this wave is not deployed, prepare its test matrix; retain older observations as historical evidence, without attributing them to new heads. Missing provenance does not prevent useful testing: label such results **running-stack only; PR inclusion unverified** in both the matrix and the table's Tested cell, even when the observed behavior passes.

Compare potentially superseded changes against current remote history before recommending further QA of duplicate branches. Distinguish patch equivalence on main from inclusion in another still-open PR; recommend reconciliation only.

## Browser control

Use the session's computer-use/browser tools. On Linux these are the `chrome-devtools` MCP tools, which attach to a dedicated, long-lived QA Chromium (`qa-browser`) in which each Chrome profile holds one logged-in role. Sessions only have them when started with `claude-qa` or `codex-qa`. Without browser tools, do not substitute desktop automation or another browser: prepare the test matrix, then stop and hand off with the relaunch command and a short summary of the wave, progress and pending decisions.

- One agent drives the QA browser at a time. Do not start, restart or close it, and do not log in or out: the user owns its logins. Ask the user when a role's session has expired or a profile's tab is missing.
- Before each identity-sensitive step, confirm the account the application itself shows in a current page snapshot. Page IDs shift when tabs open and after any reconnect, so list pages again rather than reusing earlier IDs.
- New tabs open only in the default profile. Drive other roles by navigating their profile's existing tab; never close it.
- Observe and act through accessibility snapshots; take screenshots for visual evidence. These are Chromium results: list Firefox-specific layout or behavior checks as remaining user checks.
- Keep cookies and login redirect parameters (`code=`, `state=`, `session_state=`) out of notes, reports and evidence.

When the product provides a smoke runner for the deployed stack, run it before exploratory cases and record its result as the wave's baseline.

## Test cases and execution

Translate each PR's promised behavior into named cases in `outputs/test-matrix.md`:

| Case | PR/head | Account/fixture/flags | Steps and expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|

Use **planned** for future cases awaiting deployment, **untested** for available cases not run, **blocked** for attempted cases prevented by a prerequisite, and **pass/partial/fail** for observed outcomes against the expected contract. A disabled flag or missing provider/fixture is blocked, not proof of a regression. Track execution independently of provenance; code and CI do not count as browser execution. Include relevant FE/BE dependencies and reuse one workflow to cover overlapping promises.

Check role visibility and relevant direct routes; UI gating alone does not prove server authorization. Use synthetic, clearly named fixtures and list what was created and how it can be cleaned up. Do not change deployment flags, credentials, permissions or external business records just to unblock testing. External writes, production/unknown-environment fixture writes, notifications to real users and paid jobs require explicit authorization for the target and action; otherwise leave the case blocked. Ordinary reversible fixtures in an established QA environment are within an authorized walkthrough.

Test the complete promised path where possible: create/save/reopen/use, navigation/reload, cross-user isolation, positive/empty/error cases, and cancellation or terminal state when relevant. For asynchronous workflows, distinguish user cancellation, client timeout and server completion; record timestamps in one zone and do not call an intentionally stopped job a natural failure. Do not broaden a scoped wave into an exhaustive code/security review.

For findings, separate visible observation, expected contract and suspected cause. Preserve a minimal reproduction and its exact environment; inspect code read-only where useful. Carry unresolved cases forward and retest affected workflows after verified deployment, preserving earlier results.

## Evidence and issue filing

Capture graphical findings when encountered, including before/after states where one image would mislead. Reuse a relevant existing screenshot; otherwise take one. Verify that it actually shows the claimed state. Keep synthetic data visible, exclude secrets and unnecessary personal/business data, and use stable file names linked from cases and reports.

Local report creation does not authorize GitHub postings. When issue filing or screenshot updates are requested, check existing issues, file focused FE/BE issues using repository conventions, and add evidence to matching tickets instead of duplicating them. Use relevant captions explaining what each image proves and its limitations. Upload only evidence relevant to its destination; wait for attachment completion before navigating away. Verify posted text and that the images render. Do not copy temporary signed image URLs or agent/session attribution into issues or artifacts.

## Durable artifacts and handoff

Keep one directory per wave and resume its existing files on continuation. Prefer the user's established task/output directory; otherwise use a dated QA directory outside product source. Do not overwrite a previous wave. Keep reusable instructions here and all run-specific data in the wave directory.

| Path | Contents |
|---|---|
| `work/deployment-manifest.json` | Known/unknown deployed identifiers, environment class, flags, roles, capture time and provenance |
| `work/fe-prs-current.json`, `work/be-prs-current.json` | Timestamped PR/head/CI/conflict snapshots; label stale snapshots |
| `outputs/test-matrix.md` | Promised behavior, cases, results and evidence links |
| `outputs/kolai-pr-walkthrough-report.md` | What works, mostly works, weird behavior, bugs, UI/UX and miscellaneous notes; use `walkthrough-report.md` for other products |
| `outputs/merge-recommendations.md` | Separate FE/BE tables for **all considered PRs**, including untested entries and merged contextual work |
| `outputs/qa-issues-filed.md` | Actual issue/comment links; distinguish unfiled drafts and findings |
| `outputs/qa-screenshot-updates.md` | Posted image/comment receipts when screenshots are uploaded |
| `outputs/*.jpg` or `*.png` | Captioned evidence linked by reports/cases |

Each FE/BE recommendation table uses **PR | Current readiness | QA recommendation | Tested / untested; what's left for the user**. Current readiness records draft state, primary CI and conflicts at capture time. Keep QA outcome separate, express candidates conditionally, and name missing checks. A clean Git merge status means no textual conflicts, not proven runtime compatibility.

Finish with a brief self-contained summary, the two concise tables, consequential findings and issue links, and concrete remaining user checks. Link the detailed artifacts. State that the user will do additional testing and decide/perform merging. Do not end by offering to merge.
