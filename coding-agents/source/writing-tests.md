---
description: "Use when writing or backfilling unit/integration tests, before the first test of a task — and again the moment a test of documented behavior unexpectedly fails against existing code, or you feel the pull to adjust an assertion, add todo/skip, or extend a mock to get the suite green."
mode: skill
---

# Writing Tests

A test's job is to pin the contract so a future regression fails loudly. A green suite is a side effect, never the goal.

## The contract, not the code

The source of truth is the documented contract: docstring, types, issue, spec, observable user behavior — not the implementation.

If your test of documented behavior fails against existing code, you have probably found a bug. STOP. First check the contract is current — callers, git history, the issue; a stale docstring is a finding to raise, not one to settle yourself. Then surface the bug prominently. Fix it if in scope. If not, keep the assertion on the contract and land it as an expected failure that breaks the suite once the bug is fixed — `@pytest.mark.xfail(strict=True, raises=AssertionError, reason="<issue>")`, Jest `test.failing`, Vitest `test.fails` — and link or file the issue. Any error satisfies an expected failure, so make sure it fails for the bug's reason, not a typo. **Never:**

- rewrite the assertion to match what the code does
- mark it `todo`/`skip`/non-strict `xfail` so the suite exits 0
- delete the test

A green test asserting broken behavior is worse than no test: it certifies the bug as intended and makes the eventual fix "break tests". Pinning current behavior (characterization tests) is legitimate only when explicitly requested.

## Behavior-first

Test through the public API with realistic inputs; assert observable outcomes — return values, persisted state, rendered output, emitted requests. Not internal state, not mock-call counts (unless the call is itself the contract, e.g. "never calls the admin endpoint as non-admin"). A behavior-preserving refactor must keep the test green; a behavior change must break at least one test.

## Fit the suite

Use the repo's existing harness — its runner, layout, fixtures and factories — before writing helpers of your own. Test at the level the behavior lives: unit for logic, integration when it crosses a component or process boundary. One test per distinct behavior; parametrize variants rather than copying. Don't test trivial glue, plain accessors, or the framework.

## Make wrong behavior detectable

- **Boundaries:** test one unit inside and one unit outside every edge — expiry at exactly t+ttl, a cap at max and max+1, empty/one/many.
- **Discriminating fixtures:** give every entry distinct values so first-wins vs last-wins, sorted vs insertion-order actually produce different assertions.
- **Exact assertions:** full expected values/shapes, not truthy/defined/length-only.
- **Give the bug a window:** for races, debounce, "never does X" claims — create the opportunity for the wrong behavior, then assert it didn't happen.
- **Vacuity self-check:** for each test, name the single-line mutation (flipped comparison, removed guard, dropped await) that would make it fail. Can't name one → the test asserts nothing; strengthen or delete it. For load-bearing logic, actually apply a mutation or two and watch tests go red.

## Mocks and environment

Mock only true boundaries — network, clock, external services. Never the unit under test, never the framework it sits on. Unmatched traffic at a mock boundary must fail loudly, not dissolve into empty 200s. Inject clocks/randomness; fake timers only where time is the behavior, with paired setup/teardown. Type fixtures against the real schema so contract drift breaks compilation, not production.

## Regression tests

Reproduce the bug red before fixing it green, and encode the bug story in a header comment: what broke, why, which assertion now pins it.

## Red flags — stop and reconsider

- "I'll adjust the test to match what the code actually does"
- "todo/skip for now so CI passes"
- The only assertion is `toBeTruthy()`/`toBeDefined()`/`assert result`
- Asserting the value your own mock returned
- No test in the file fails if you flip the module's central comparison
