---
name: finishing-a-development-branch
description: Use when implementation is complete and the next integration step needs a decision
---

# Finishing a Development Branch

## Overview

**Core principle:** Verify the state → report available next steps → follow the user's direction.

Never merge, delete a branch, discard changes, or remove a worktree without
explicit user authorization. A green check or a generic request to proceed
does not authorize merging.
Keep worktrees and branches by default after reporting readiness; do not treat
successful integration as automatic authorization to delete them.

## Step 1: Check evidence

Run the checks required by the user and repository guidance. Do not claim a
check passed unless you observed it.

If a required check failed, report it and investigate as the user or project
instructions direct. Do not run extra tests solely to enter a completion menu.

## Step 2: Detect Environment

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
# Capture before changing directories if cleanup is authorized later.
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

This distinguishes a normal checkout from an externally managed worktree:

| State | Workspace handling |
|-------|--------------------|
| `GIT_DIR == GIT_COMMON` (normal repo) | No worktree cleanup needed |
| `GIT_DIR != GIT_COMMON`, named branch | Preserve unless user authorizes cleanup |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Externally managed; preserve it |

## Step 3: Determine Base Branch

Identify the base only when an authorized merge or PR needs it. Use repository
instructions and branch metadata; ask if a real uncertainty affects the target.

## Step 4: Identify any remaining decision

Follow any integration direction the user already gave. If a protected action
such as merge or cleanup is not authorized, report that the work is ready and
ask only for that authorization. Do not force a fixed menu when no choice is
needed. For an authorized PR, use the repository's delivery workflow; in this
setup that means `deliver`, then `babysit` until CI and review are ready.

## Step 5: Perform authorized integration

### Merge locally

```bash
# Get main repo root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge only after explicit authorization and by the repository's merge procedure.
git checkout <base-branch>
git merge <feature-branch>

# Run the repository's required checks.
<check command>
```

If tests fail on the merged result: stop, leave the worktree and branch in
place, and investigate — nothing has been pushed, so the merge is local
and recoverable.

Once the merged result is green, report the state. Clean up the worktree or
delete the branch only if the user authorized that cleanup:

```bash
git branch -d <feature-branch>
```

### Push and create a PR

```bash
git push -u origin <feature-branch>
# From a detached HEAD, name the new branch on the remote:
# git push origin HEAD:refs/heads/<new-branch>
```

Then follow the repository's delivery workflow and PR conventions. Report the
URL and follow the configured CI and review watcher if the user authorized
delivery.

Keep the worktree — your human partner iterates on PR feedback there.

### Keep the branch

Preserve the branch and worktree, and report their names and paths.

### If your human partner asks to discard the work

Discard work only when the user clearly requested it. If the request is
ambiguous, explain what would be lost and ask a concise clarification. When
authorized:

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then clean up the worktree (Step 6) and force-delete the branch:

```bash
git branch -D <feature-branch>
```

## Step 6: Cleanup Workspace

**Runs only when the user authorized cleanup.** Otherwise preserve the
worktree. If cleanup was authorized, change directory to the
main repo root — worktree removal must run from outside the worktree —
and use the `GIT_DIR`/`GIT_COMMON`/`WORKTREE_PATH` values captured in
Step 2, from before that directory change.

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

**If `WORKTREE_PATH` is under `.worktrees/` or `worktrees/`:** This workflow
created the worktree — we own cleanup when authorized:

```bash
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**If removal is refused** (`contains modified or untracked files`): the
worktree holds files that exist nowhere else — uncommitted plans, notes,
or scratch work. Never `--force` on your own initiative. Show your human
partner what is at stake and ask:

```bash
git -C "$WORKTREE_PATH" status --porcelain -uall
```

```
Worktree removal refused — these files were never committed:

<file list>

1. Commit them to <branch> before cleanup
2. Move them into <main repo root>
3. Delete them (unrecoverable)

Which?
```

Carry out only actions the user explicitly authorized, then remove the
worktree if cleanup was authorized. Otherwise preserve it and report what is
still needed.

**Otherwise:** The host environment owns this workspace — leave it in
place. If your platform provides a workspace-exit tool, use it.

## Quick Reference

| User direction | Action |
|----------------|--------|
| Merge authorized | Follow the repository's merge procedure |
| PR authorized | Use the delivery workflow and follow CI/review |
| No integration direction | Report ready state; ask only before a protected action |
| Cleanup authorized | Preserve unique files, then remove only the authorized workspace |
| Discard explicitly requested | Discard only the named branch/worktree |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier this session" | Report evidence from the current tree and run checks required by project guidance. |
| "They obviously want it merged" | Merge only when the user explicitly authorizes it. |
| "They seem done with this feature — I'll offer to discard it" | Preserve the branch and workspace unless the user asks to discard them. |
| "'Yeah, get rid of it' counts as authorization" | If the target or consequence is ambiguous, clarify before deleting. |
| "The PR is up, so the worktree is clutter now" | PR feedback gets fixed in that worktree. It stays until the work lands. |
| "This other worktree looks stale — I'll clean it too" | Clean up only worktrees under `.worktrees/` or `worktrees/`. Everything else belongs to the host. |
| "Removal refused — `--force` is just finishing the cleanup" | The refusal means files exist only in that worktree. `--force` destroys them permanently. Show your human partner and ask. |
| "The merged-result failure is probably flaky" | A failing merged result stops everything. Branch and worktree stay put while you investigate. |
| "The base branch is obviously main" | Confirm the target from repo instructions and branch metadata before an authorized merge. |
| "The push was rejected — force-push will fix it" | A rejected push means the remote moved. Investigate; force-push only on your human partner's explicit request. |
