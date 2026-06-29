---
description: "Use when you must understand a pull request deeply enough to approve or sign off on it — other reviews already passed but you haven't gone deep, you're taking ownership of unfamiliar code, or you want your own mental model rather than trusting a green check. Builds load-bearing invariants, cross-module call-chains with file:line locations to confirm, per-invariant test coverage, and the judgment calls approval commits you to."
mode: primary
permission:
  bash: allow
  edit: deny
  webfetch: deny
---

# Understanding a PR well enough to approve it

Approving a PR means **vouching that the design decisions are ones you accept** — not just "no bugs were found." Other reviews tell you it's *probably* correct; they cannot tell you whether the trade-offs are right for you. This skill builds your own defensible understanding fast, by reducing a large diff to a handful of load-bearing claims you can each confirm.

**Core move:** turn "read 2000 lines" into "verify N invariants, each at a known location, each with a known test." Ground EVERY claim in a `file:line` reference. Separate what you *verified* from what you *accept on judgment* from what you *couldn't check*.

**Scope check first:** attribute claims to what the PR's *diff* actually changes (`gh pr diff <n> --name-only`), then read the surrounding code it relies on. A stacked PR or a moved merge-base means the branch (or `main`) can contain code this PR did not add — don't credit/blame it to this PR.

**If a reviewer's reading guide came with the PR** (the IC pipeline produces one), start from its "read closely" list — it already routed attention onto the load-bearing hunks, so it's the fastest way into a large diff. Treat it as a lead, not gospel: confirm each flagged section yourself, and stay alert for anything parked in "safe to skip" that your invariants say is actually load-bearing. The guide saves you the triage; it does not stand in for your verification — an unconfirmed claim is still trust, not understanding.

## When to use

- You're asked to approve / sign off on a PR you didn't fully write, or haven't gone deep on.
- Reviews already passed but you want to be able to *defend* the approval, not just trust the check.
- You're taking ownership of unfamiliar code and need its mental model.

Not for: a PR you wrote and know cold, or a trivial diff where reading it once is enough.

## Produce these artifacts

Work in this order. Lead with the part only the human can decide.

### 1. What approving commits you to (the judgment calls)
List the 1–3 decisions approval implicitly signs off on that **no reviewer can make for you**: deferred work, accepted limitations, risk bought on faith (e.g. "the orphaned-record window is acceptable until the follow-up PR", "no rate limit until M6 — gateway must cover it"). If the author already made these calls, say so and confirm consistency. If a deferral looks risky *for this deployment*, push back here.

### 2. Invariants table (the spine)
Extract the handful of claims the whole PR rests on — the things that, if violated, are a bug or security hole. Derive them by asking *"what must be true for this to be correct/safe?"* For each:

| Invariant | Confirm in | The one thing to check | Test |
|-----------|-----------|------------------------|------|
| Tenant scope comes from the row, not the caller | `views.py:108` | identity built from `workflow.org_id`, never request body | ✓ `test_x.py::test_isolation` |
| Real errors don't collapse into the catch-all 404 | `views.py:88-99` | only the 5 enumerated cases 404; a DB error still 500s | ⚠ partial — 3/5 variants only |

The **Test column is required** (see §"Finding test coverage"). It is the difference between "I read it and it looks right" and "this is pinned by an assertion."

### 3. Call-chains
Trace each entrypoint (endpoint / handler / job / public function) across functions and modules, annotated with `file:line` and what each hop does. Mark process/IO boundaries explicitly (DB, queue, network, RPC). Show where two entrypoints **converge on a shared function** — those waists are where a single check (auth, validation) protects everything, so they're high-value to confirm. A compact ASCII diagram beats prose here.

### 4. Deep walks (2–3)
Pick the trickiest reasoning chains — where "looks fine" hides a misunderstanding — and walk them step by step. The usual suspects: **ordering/atomicity** (what's the worst interleaving? what's left half-written?), **concurrency/races** (is there an `await` between a check and a mutation?), **partial failure** (some side effects done, then an error), **idempotency** (what does a second run / retry do?). Naming *why* a known gap can't be fixed by the existing code is how you prove you understand a deferral rather than just accepting it.

### 5. Reading order
Give a path through the files that mirrors **execution order**, not file order — it coheres far faster (e.g. "request handler top-to-bottom → the service it calls → the shared waist → the readback loop").

### 6. Self-verification the human runs
Concrete, cheap checks they can run to confirm your claims rather than trust them: a `grep` that proves an invariant holds repo-wide, the exact tests to run, one value/event to trace end-to-end.

### 7. Residual risks
Deferrals, latent issues not reachable on today's paths but one refactor away, and **tests that skip in CI** (so a green run proves less than it appears).

## Finding test coverage (the Test column)

For every invariant and every risky call-chain, find whether a test pins it:

1. Tests usually mirror `src/` under `tests/` — for `src/x/y.py`, look in `tests/x/test_y.py`.
2. `grep` test names for the behavior, then **read the assertion**, not just the name.
3. Classify and cite the location:
   - **✓ covered** — an assertion checks the observable outcome. Cite `tests/…::test_name`.
   - **⚠ weak / partial / CI-skipped** — exists but asserts the wrong thing, covers only some cases, mocks away the real path, or is gated on a service CI doesn't have (skips silently → green proves nothing). Say which.
   - **✗ none** — no test pins this invariant.
4. **Surface every ✗ and ⚠ explicitly.** Those are the invariants where your approval rests on reading, not on CI — exactly where to spend scrutiny.

## Style

- Every claim → a clickable `file:line`. No location = you're trusting, not verifying.
- Be honest and specific: separate "verified", "accepted on judgment", and "couldn't check". Don't perform confidence you don't have.
- Push back when a deferral or accepted gap is risky for the actual deployment context.
- Use short insight notes for the non-obvious *why* (the design reason behind a structure), not for restating what the code says.

## Red flags — you are NOT done

- An invariant with no "confirm in" location → you're trusting, not verifying.
- Blanks in the Test column you didn't investigate.
- You can't state what approval commits the human to.
- You only read the diff, not the surrounding invariants the diff relies on.
- Everything is "looks good" with no separation of verified vs. judgment vs. unchecked.
