---
name: requesting-code-review
description: Use when the user or repository requires a review, or the change's scope and risk benefit from a fresh perspective
---

# Requesting Code Review

Use the repository's existing review agent or workflow with focused context.
For a focused review, use [code-reviewer.md](code-reviewer.md); for a broad
review, use `super-review`. Use cross-model `peer-review` when an independent
view would help with a consequential decision.

**Core principle:** Review early, review often.

## When to Request Review

Ask for review when the user or repository requires it, when the change's
scope or risk benefits from a fresh perspective, or before an authorized
integration step.

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or: git merge-base origin/main HEAD
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch code reviewer subagent:**

Dispatch the repository's `reviewer` agent using [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `[DESCRIPTION]` - Brief summary of what changed
- `[PLAN_OR_REQUIREMENTS]` - What it should do
- `[BASE_SHA]` - Starting commit, when useful
- `[HEAD_SHA]` - Ending commit, when useful

**3. Act on feedback:**
- Grade findings by their likely effect; reviewer labels are input, not policy
- Fix material issues that violate the requirement or create user risk
- Record lesser issues for the user when they affect a meaningful tradeoff
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | cut -d' ' -f1)
HEAD_SHA=$(git rev-parse HEAD)

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from docs/brainstorms/YYYY-MM-DD-topic.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'll just review the diff myself instead of dispatching a reviewer" | You're the coordinator — reviewing the diff inline burns the context window you need to keep driving the work. Dispatch a reviewer subagent: the diff and the evaluation live in its context, and only the findings come back to you. |
| "The reviewer needs my whole session history to understand the change" | Hand it precisely crafted context, never your session's history. That keeps the reviewer on the work product, not your thought process. |

Use judgment about review depth. This skill does not override project review
workflows such as `super-review` or cross-model `peer-review`.

## When a finding seems wrong

- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: [code-reviewer.md](code-reviewer.md)
