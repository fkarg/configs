# Codex sandbox CLI authentication design

## Problem

Codex sessions using the normal `workspace-write` sandbox can run `gh`, but
GitHub CLI commands that need the system keyring appear unauthenticated. A few
read-only command shapes currently work only because `default.rules` lets those
exact invocations escape the sandbox. Other commands such as `gh api`,
`gh label`, and `gh issue create` stay inside the sandbox, cannot reach the
desktop keyring over D-Bus, and fall back to anonymous GitHub access.

`claude -p` has separately reported an expired OAuth token from normal Codex
permission modes. Its credential refresh path should not be assumed to work in
the Codex sandbox, and permanently allowing an arbitrary nested agent process
outside that sandbox would grant more authority than necessary.

Codex also reports that it cannot find `bubblewrap` on `PATH` and therefore
uses its bundled copy. The fallback works, but the host configuration should
provide the expected sandbox executable explicitly.

## Evidence and root causes

- Transcript evidence shows `gh auth status`, `gh issue list`, and `gh pr view`
  succeeding under `workspace-write` when their exact command shapes matched
  existing rules, while unmatched authenticated operations failed with HTTP
  401 or anonymous rate limits. Switching to Approve All made the same commands
  succeed immediately.
- A sandbox test with `/run/user/1000/bus` added to the existing Codex network
  proxy Unix-socket allowlist made `gh auth status` succeed without disabling
  the workspace sandbox.
- Claude's failures explicitly reported an expired OAuth token. The transcript
  does not provide a clean same-permission-mode recovery test because the Codex
  permission model changed between the failing call and the later successful
  authentication check.
- Codex's sandbox warning confirms that an explicit host `bubblewrap` package is
  absent even though Codex can fall back to a bundled implementation.

## Design

### Provide bubblewrap declaratively

Add `bubblewrap` to the shared Nix developer tooling packages alongside the
agent harnesses. This makes the executable available on configured NixOS hosts
without changing Codex's sandbox policy or relying on its bundled fallback.

### Give sandboxed GitHub CLI access to the keyring

Extend the existing `features.network_proxy` configuration in
`coding-agents/configs/codex/shared.toml` with this exact Unix socket:

```toml
unix_sockets = { "/run/user/1000/bus" = "allow" }
```

The socket is the verified D-Bus user-bus path on the Linux hosts. It lets
sandboxed `gh` use the same keyring-backed credentials as the user's shell, so
all `gh` subcommands can remain inside the normal workspace sandbox. Existing
domain restrictions for GitHub and Anthropic remain unchanged.

The path is intentionally explicit rather than dynamically expanded in the
merge script. These machines use UID 1000, the value has been tested directly,
and adding generalized path interpolation would be extra mechanism for no
current requirement. On macOS the Linux socket path is absent and inert.

Existing out-of-sandbox rules for narrowly scoped read-only `gh` commands may
remain for compatibility. No broad `gh api` or write-command escape is added.

### Prompt before running Claude outside the sandbox

Add an execution-policy rule for the `claude -p` prefix with decision `prompt`.
When Codex invokes Claude for an independent review or diagnosis, the user can
approve that individual host execution without changing the entire Codex
session to Approve All.

The rule must not use decision `allow`: `claude -p` is another agent process,
later arguments can materially alter its permissions and tool use, and a prefix
rule cannot safely constrain every later flag. `claude auth status` remains a
normal sandboxed command.

Do not make Claude's configuration directory writable inside the sandbox.
That directory also contains settings and hooks, so widening filesystem access
would expose more mutable state than credential refresh requires.

## Security properties

- The workspace sandbox stays enabled for ordinary work and for `gh` itself.
- GitHub credential access is limited to the user's existing D-Bus session
  socket; no token is copied into tracked config or environment variables.
- Existing outbound proxy domain restrictions remain in place.
- A nested Claude agent reaches the host only after a focused approval prompt.
- No blanket command family or full-session permission escalation is required.

## Verification

Automated checks will cover the serialized Codex configuration and execution
policy match for `claude -p`, while confirming unrelated Claude invocations do
not match that rule. Existing merge and rule tests must remain green.

Host-level verification will confirm:

1. `bubblewrap` resolves on `PATH` after applying the Nix configuration.
2. Under Codex `workspace-write`, `gh auth status` and an authenticated command
   not covered by the legacy escape rules succeed without Approve All.
3. `claude -p` produces a focused approval prompt and succeeds after approval.
4. The coding-agents Ansible role renders and merges the curated Codex config
   without disturbing host-local trust or authentication state.

## Rollout and rollback

Apply the NixOS package change through the normal host rebuild and the Codex
configuration through the `coding_agents` Ansible role. Each change is additive
and independently reversible: remove the package, socket entry, or prompt rule
and reapply the corresponding configuration. No credential migration or secret
rotation is involved.
