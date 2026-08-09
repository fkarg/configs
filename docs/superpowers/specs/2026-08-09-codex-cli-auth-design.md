# Codex sandbox CLI authentication design

## Problem

Codex sessions using the normal `workspace-write` sandbox cannot read GitHub
CLI credentials from the desktop keyring. A few `gh` command shapes work only
because existing execution-policy rules run them on the host. Unmatched commands
such as `gh api`, `gh label`, and `gh run` stay sandboxed and fall back to
anonymous GitHub access.

`claude -p` has separately reported expired OAuth tokens from normal Codex
permission modes. Running a nested agent outside the sandbox should remain an
explicit per-call decision rather than an unconditional capability.

Codex also reports that it cannot find `bubblewrap` on `PATH` and uses its
bundled fallback. Finally, Codex recently defaults approval review to the user
at startup instead of the desired automatic reviewer.

## Evidence and corrected root cause

- Transcripts show matched `gh` commands succeeding in `workspace-write`, while
  unmatched authenticated operations fail with HTTP 401 or anonymous rate
  limits. Approve All makes the same commands succeed immediately.
- Host `gh auth status` succeeds from the keyring and connects to the user D-Bus
  socket at `/run/user/1000/bus`.
- Codex 0.147 still denies a real connection to that socket from
  `workspace-write`, even with the documented socket allowlist and the
  all-Unix-sockets diagnostic switch. An ephemeral agent with user rules
  disabled reproduced the 401 for `gh label list`. The socket configuration is
  therefore not a working fix and must not be shipped.
- Claude's failures explicitly reported an expired OAuth token. The transcript
  does not provide a clean same-permission-mode recovery because the Codex
  permission model changed before the later successful check.
- Codex's warning confirms that an explicit host `bubblewrap` package is absent
  even though its bundled implementation works.

## Design

### Provide bubblewrap declaratively

Add `bubblewrap` to the shared Nix developer tooling packages alongside the
agent harnesses. This supplies the expected sandbox executable on NixOS hosts
without changing Codex's sandbox policy.

### Run every GitHub CLI invocation on the host

Replace the command-specific GitHub rules with one execution-policy rule:

```python
prefix_rule(
    pattern = ["gh"],
    decision = "allow",
    justification = "GitHub CLI always needs access to host keyring credentials",
)
```

This deliberately covers all subcommands, including API calls, mutations,
aliases, and extension execution. It is broader than the earlier read-only
policy, but it is the user's explicit choice in exchange for reliable keyring
authentication without repeated prompts or Approve All mode.

No GitHub token is copied into tracked config, plaintext storage, or the sandbox
environment. The normal workspace sandbox remains enabled for non-`gh`
processes.

### Prompt before running Claude outside the sandbox

Add an execution-policy rule for the `claude -p` prefix with decision `prompt`.
The user can approve an individual cross-model review or diagnosis without
changing the whole Codex session to Approve All.

Do not use decision `allow`: `claude -p` is another agent process and later
arguments can materially alter its permissions and tool use. Do not make
Claude's configuration directory writable inside the sandbox because it also
contains settings and hooks.

### Default approval review to “Approve for me” on every machine

Keep `approval_policy = "on-request"` and add this top-level shared setting:

```toml
approvals_reviewer = "auto_review"
```

This sends eligible approval prompts to Codex's automatic reviewer by default
while retaining `workspace-write`. Because `shared.toml` is merged by the
cross-platform `coding_agents` role, the default applies to every managed
machine rather than only the current host.

## Security properties and accepted tradeoffs

- The workspace sandbox stays enabled for ordinary commands.
- All `gh` processes run unsandboxed and without prompting. They can read the
  host keyring, mutate GitHub state, and execute installed GitHub extensions;
  this breadth is intentional and pinned by tests.
- No GitHub or Claude credential is added to the repository or general process
  environment.
- `claude -p` still requires a focused approval decision.
- Other sandbox escalations remain under the `on-request` policy, reviewed by
  the automatic reviewer rather than defaulting to user prompts.

## Verification

Automated tests must prove:

1. Representative read, write, API, run, and extension `gh` invocations all
   resolve to `allow`.
2. `claude -p` resolves to `prompt`, while `claude auth status` has no match.
3. Merging the real shared config produces `approval_policy = "on-request"`,
   `approvals_reviewer = "auto_review"`, and `sandbox_mode = "workspace-write"`.
4. The Nix developer-tooling expression parses with `bubblewrap` present.

Host verification after applying configuration should confirm an unmatched
authenticated `gh` command succeeds, `claude -p` takes the focused approval
path, and new Codex sessions start with automatic approval review.

## Rollout and rollback

Apply the Nix package through the normal NixOS rebuild and the shared Codex
configuration and rules through the `coding_agents` Ansible role. Rollback is
independent: remove `bubblewrap`, restore narrower GitHub rules, remove the
Claude prompt rule, or remove `approvals_reviewer`, then reapply the relevant
configuration. No credential migration or secret rotation is involved.
