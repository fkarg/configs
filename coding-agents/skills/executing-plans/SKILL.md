---
name: executing-plans
description: Use when carrying out a substantial written implementation plan in the current session
---

# Executing Plans

Execute an authorized plan yourself, task by task. Follow the user's and
repository's instructions. Use the current checkout unless isolation is
required by repository instructions or concurrent writers. Do not commit,
discard changes, or clean up workspaces unless authorized.

Use subagent-driven-development when the user requests it or when independent
chunks clearly benefit from delegation. Otherwise implement in the main
session and use a fresh review when the task warrants one.

## Setup

Read the plan and any referenced specification. Treat the specification and
the user's latest direction as authoritative when the plan conflicts with
them. Create a task checklist. For substantial work, keep a concise progress
ledger beside the plan or in the repository's established scratch location;
do not create a new workspace convention solely for this skill.

Before starting, scan for shared interfaces between tasks and identify
conflicts. Resolve unclear scope or consequential choices with the user;
make routine implementation decisions yourself and record decisions that
could affect later tasks.

## Task loop

For each task:

1. Read its exact instructions and relevant context.
2. Make the smallest change that meets the plan and the current repository
   conventions.
3. Run the checks the user or repository requires. A plan's
   existence alone does not require tests. When a focused automated test is
   required and supported, follow `test-driven-development`.
4. Compare observed results with the plan's expected outcomes. If the plan is
   wrong, adjust only as needed to meet the spec, explain the decision in the
   ledger, and continue. If the implementation is wrong, diagnose the cause
   before changing it.
5. Record the result and mark the task complete.

Preserve unrelated changes and scratch files. After compaction, inspect the
ledger, working tree, and git history before resuming; do not assume a task
needs repeating just because it is no longer in context.

## Review and completion

When useful, ask a fresh reviewer to assess the complete change against the
plan, specification, and likely failure modes. Follow repository peer-review
requirements. Grade findings by their effect on users; address material
defects and verify fixes with the smallest relevant check required by project
instructions. Record
deferred issues and decisions with their reason and potential cost.

Before reporting completion, state which checks you ran and their observed
results. Do not claim broader verification than the evidence supports.
Preserve the branch, workspace, and plan artifacts unless the user authorized
cleanup. Follow `finishing-a-development-branch` for any integration step.
