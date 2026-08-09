# Codex CLI Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Codex's normal workspace sandbox enabled while making keyring-backed `gh` commands usable, prompting narrowly for host-side `claude -p`, and providing bubblewrap explicitly on NixOS hosts.

**Architecture:** The curated Codex config will allow only the verified user D-Bus socket through its existing network proxy, so GitHub CLI stays sandboxed and uses the host keyring. Execution policy will prompt for the specific nested-agent prefix `claude -p`, and the shared Nix package list will provide the sandbox binary Codex otherwise bundles.

**Tech Stack:** TOML, Codex Starlark execution policy, Python `unittest`, NixOS modules

---

### Task 1: Allow sandboxed GitHub CLI to reach the user keyring

**Files:**
- Modify: `coding-agents/test_merge_codex_config.py`
- Modify: `coding-agents/configs/codex/shared.toml`

- [ ] **Step 1: Write the failing real-config regression test**

Add `import tomllib`, define the real shared-config path, and add this test to `MergeCodexConfigTests`:

```python
SHARED_CONFIG = Path(__file__).parent / "configs" / "codex" / "shared.toml"

def test_shared_config_allows_the_user_dbus_socket(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        target = Path(temp_dir) / "config.toml"

        merge_codex_config.merge(SHARED_CONFIG, target)

        merged = tomllib.loads(target.read_text())
        self.assertEqual(
            merged["features"]["network_proxy"]["unix_sockets"],
            {"/run/user/1000/bus": "allow"},
        )
```

- [ ] **Step 2: Run the regression test and verify RED**

Run:

```bash
python3 -m unittest coding-agents.test_merge_codex_config.MergeCodexConfigTests.test_shared_config_allows_the_user_dbus_socket
```

Expected: `ERROR` with `KeyError: 'unix_sockets'`, proving the real shared config lacks the required socket.

- [ ] **Step 3: Add the exact socket to the curated proxy config**

Replace the `network_proxy` value in `coding-agents/configs/codex/shared.toml` with:

```toml
network_proxy = { enabled = true, domains = { "api.github.com" = "allow", "api.anthropic.com" = "allow" }, unix_sockets = { "/run/user/1000/bus" = "allow" } }
```

Update the nearby comment to state that both outbound domains and the user D-Bus socket are narrowly allowlisted.

- [ ] **Step 4: Run the focused and full merge tests and verify GREEN**

Run:

```bash
python3 -m unittest coding-agents.test_merge_codex_config.MergeCodexConfigTests.test_shared_config_allows_the_user_dbus_socket
python3 -m unittest coding-agents/test_merge_codex_config.py
```

Expected: the focused test reports `Ran 1 test ... OK`; the file reports `Ran 3 tests ... OK`.

- [ ] **Step 5: Commit the socket configuration and regression test**

```bash
git add coding-agents/test_merge_codex_config.py coding-agents/configs/codex/shared.toml
git commit -m "codex: expose user keyring to sandboxed gh"
```

### Task 2: Prompt narrowly for host-side Claude print mode

**Files:**
- Modify: `coding-agents/test_codex_rules.py`
- Modify: `coding-agents/configs/codex/rules/default.rules`

- [ ] **Step 1: Write the failing execution-policy regression test**

Add this test to `CodexRulesTests`:

```python
def test_prompts_for_claude_print_mode_only(self) -> None:
    self.assertEqual(
        decision_for("claude", "-p", "Review this design"),
        "prompt",
    )
    self.assertIsNone(decision_for("claude", "auth", "status"))
```

- [ ] **Step 2: Run the regression test and verify RED**

Run:

```bash
python3 -m unittest coding-agents.test_codex_rules.CodexRulesTests.test_prompts_for_claude_print_mode_only
```

Expected: `FAIL` because the actual decision for `claude -p` is `None`.

- [ ] **Step 3: Add the minimal prompt rule**

Append this rule to `coding-agents/configs/codex/rules/default.rules` without altering unrelated local rules:

```python
prefix_rule(
    pattern = ["claude", "-p"],
    decision = "prompt",
    justification = "Claude print mode needs host credential refresh and runs another agent",
    match = ["claude -p Review this design"],
    not_match = ["claude auth status"],
)
```

Update the existing GitHub rule comment to explain that the read-only host rules remain as compatibility fallbacks while ordinary sandboxed GitHub commands use the D-Bus socket.

- [ ] **Step 4: Run the focused and full rule tests and verify GREEN**

Run:

```bash
python3 -m unittest coding-agents.test_codex_rules.CodexRulesTests.test_prompts_for_claude_print_mode_only
python3 -m unittest coding-agents/test_codex_rules.py
```

Expected: the focused test reports `Ran 1 test ... OK`; the file reports `Ran 6 tests ... OK`.

- [ ] **Step 5: Commit the Claude execution policy and regression test**

```bash
git add coding-agents/test_codex_rules.py coding-agents/configs/codex/rules/default.rules
git commit -m "codex: prompt for host-side claude print mode"
```

### Task 3: Provide bubblewrap explicitly on NixOS hosts

**Files:**
- Modify: `nixos/shared/packages/developer-tooling.nix`

- [ ] **Step 1: Add bubblewrap beside the agent harnesses**

Insert `bubblewrap` before `claude-code` in the `# agent harnesses` package group:

```nix
    # agent harnesses
    bubblewrap
    claude-code
```

- [ ] **Step 2: Verify the Nix expression parses**

Run:

```bash
nix-instantiate --parse nixos/shared/packages/developer-tooling.nix >/dev/null
```

Expected: exit status 0 with no stderr.

- [ ] **Step 3: Commit the package declaration**

```bash
git add nixos/shared/packages/developer-tooling.nix
git commit -m "nixos: add bubblewrap to developer tooling"
```

### Task 4: Verify the integrated configuration and land it

**Files:**
- Verify: `coding-agents/configs/codex/shared.toml`
- Verify: `coding-agents/configs/codex/rules/default.rules`
- Verify: `nixos/shared/packages/developer-tooling.nix`

- [ ] **Step 1: Run all relevant automated checks**

Run:

```bash
python3 -m unittest coding-agents/test_codex_rules.py coding-agents/test_merge_codex_config.py
nix-instantiate --parse nixos/shared/packages/developer-tooling.nix >/dev/null
git diff --check origin/master...HEAD
```

Expected: `Ran 9 tests ... OK`, the Nix parse exits 0, and `git diff --check` prints nothing.

- [ ] **Step 2: Inspect the exact execution-policy decisions**

Run:

```bash
codex execpolicy check --rules coding-agents/configs/codex/rules/default.rules -- claude -p "Review this design"
codex execpolicy check --rules coding-agents/configs/codex/rules/default.rules -- claude auth status
```

Expected: the first JSON result contains `"decision":"prompt"`; the second has no matched decision.

- [ ] **Step 3: Review the final branch history and changed files**

Run:

```bash
git status --short --branch
git log --oneline --decorate origin/master..HEAD
git diff --stat origin/master...HEAD
```

Expected: a clean task worktree with only the design, plan, socket config/test, Claude rule/test, and Nix package commits relative to `origin/master`.

- [ ] **Step 4: Fetch and fast-forward the branch if remote master advanced**

Run:

```bash
git fetch origin
git rebase origin/master
```

Expected: the rebase completes without overwriting the dirty primary checkout. Re-run Step 1 after any replayed commits.

- [ ] **Step 5: Push the verified branch directly to master**

```bash
git push origin HEAD:master
```

Expected: a fast-forward update of `origin/master`. Do not update, reset, or clean the primary checkout; its existing `top`, `journalctl`, and unrelated untracked changes remain user-owned local state.
