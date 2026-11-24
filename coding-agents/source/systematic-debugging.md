---
description: "Use when the cause of a bug, test failure, or unexpected behavior is not yet established."
mode: skill
---

# Systematic Debugging

Establish a likely cause before changing code. For a scoped GitHub issue
handled by `ic`, use IC's evidence-backed whys, independent diagnosis, and
falsifying observation; this skill does not replace that workflow.

For other unfamiliar failures:

1. Reproduce or otherwise observe the failure and identify the expected behavior.
2. Trace the affected path and list plausible causes that fit the evidence. In
   a multi-component path, inspect the relevant input and output at each
   boundary to find the first point where observed state diverges from expected
   state; then investigate that component.
3. Choose the cheapest observation that distinguishes those causes. Update the
   diagnosis when it contradicts the leading explanation.
4. Change the smallest thing that addresses the supported cause, then verify
   the reported behavior and relevant regressions.

If the cause remains uncertain, say what is known and what observation is
missing. Don't turn a plausible guess into a claim that the bug is fixed.
