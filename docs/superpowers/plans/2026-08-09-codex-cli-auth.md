# Codex CLI Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make authenticated GitHub and Claude CLI workflows reliable without defaulting whole Codex sessions to Approve All, provide bubblewrap explicitly, and start every managed machine in “Approve for me.”

**Architecture:** All `gh` invocations escape the sandbox through one explicit allow rule so they can use the host keyring. `claude -p` uses a narrower prompt rule, shared Codex config selects the automatic approvals reviewer, and the Nix package list provides bubblewrap.

**Tech Stack:** TOML, Codex Starlark execution policy, Python `unittest`, NixOS modules

---

### Task 1: Default every machine to automatic approval review

**Files:**
- Modify: `coding-agents/test_merge_codex_config.py`
- Modify: `coding-agents/configs/codex/shared.toml`

- [ ] **Step 1: Write the failing real-config regression test**

Add `import tomllib`, define the real shared config path, and add:

```python
SHARED_CONFIG = Path(__file__).parent / "configs" / "codex" / "shared.toml"

def test_shared_config_uses_automatic_approval_review(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        target = Path(temp_dir) / "config.toml"

        merge_codex_config.merge(SHARED_CONFIG, target)

        merged = tomllib.loads(target.read_text())
        self.assertEqual(merged["approval_policy"], "on-request")
        self.assertEqual(merged["approvals_reviewer"], "auto_review")
        self.assertEqual(merged["sandbox_mode"], "workspace-write")
```

- [ ] **Step 2: Run the test and verify RED**

```bash
python3 -m unittest coding-agents.test_merge_codex_config.MergeCodexConfigTests.test_shared_config_uses_automatic_approval_review
```

Expected: `ERROR` with `KeyError: 'approvals_reviewer'`.

- [ ] **Step 3: Add the persistent shared setting**

Keep the existing policy and sandbox keys, inserting:

```toml
approval_policy = "on-request"
approvals_reviewer = "auto_review"
sandbox_mode = "workspace-write"
```

Do not add the disproven D-Bus socket setting to `features.network_proxy`.

- [ ] **Step 4: Run the focused and full merge tests and verify GREEN**

```bash
python3 -m unittest coding-agents.test_merge_codex_config.MergeCodexConfigTests.test_shared_config_uses_automatic_approval_review
python3 -m unittest coding-agents/test_merge_codex_config.py
```

Expected: one focused test and all three merge tests pass.

### Task 2: Allow every GitHub CLI invocation on the host

**Files:**
- Modify: `coding-agents/test_codex_rules.py`
- Modify: `coding-agents/configs/codex/rules/default.rules`

- [ ] **Step 1: Write the failing broad-policy regression test**

Replace the read-only and mutation-specific GitHub tests with:

```python
def test_allows_all_github_commands(self) -> None:
    commands = [
        ("gh", "auth", "status", "-h", "github.com"),
        ("gh", "issue", "view", "682", "--json", "body"),
        ("gh", "pr", "create", "--title", "Example"),
        ("gh", "api", "graphql", "-f", "query={viewer{login}}"),
        ("gh", "run", "rerun", "1234"),
        ("gh", "extension", "exec", "example"),
    ]
    for command in commands:
        with self.subTest(command=command):
            self.assertEqual(decision_for(*command), "allow")
```

- [ ] **Step 2: Run the test and verify RED**

```bash
python3 -m unittest coding-agents.test_codex_rules.CodexRulesTests.test_allows_all_github_commands
```

Expected: mutation commands still resolve to `prompt`, while unlisted command
families resolve to no decision.

- [ ] **Step 3: Replace every GitHub rule with one allow rule**

```python
# GitHub CLI credentials live in the host keyring and are unavailable in the
# workspace sandbox. All gh commands run on the host without prompting.
prefix_rule(
    pattern = ["gh"],
    decision = "allow",
    justification = "GitHub CLI always needs access to host keyring credentials",
    match = [
        "gh auth status -h github.com",
        "gh issue view 682 --json body",
        "gh pr create --title Example",
        "gh api graphql -f query={viewer{login}}",
        "gh run rerun 1234",
        "gh extension exec example",
    ],
)
```

Remove the narrower GitHub allow and prompt rules so no more-restrictive match
overrides this decision.

- [ ] **Step 4: Run the focused and full rule tests and verify GREEN**

```bash
python3 -m unittest coding-agents.test_codex_rules.CodexRulesTests.test_allows_all_github_commands
python3 -m unittest coding-agents/test_codex_rules.py
```

Expected: one focused test and all five rule tests pass.

### Task 3: Prompt narrowly for host-side Claude print mode

**Files:**
- Modify: `coding-agents/test_codex_rules.py`
- Modify: `coding-agents/configs/codex/rules/default.rules`

- [ ] **Step 1: Add the failing execution-policy test**

```python
def test_prompts_for_claude_print_mode_only(self) -> None:
    self.assertEqual(decision_for("claude", "-p", "Review this design"), "prompt")
    self.assertIsNone(decision_for("claude", "auth", "status"))
```

- [ ] **Step 2: Verify RED, then add the minimal rule**

Run the focused test and confirm `claude -p` initially resolves to no decision,
then add:

```python
prefix_rule(
    pattern = ["claude", "-p"],
    decision = "prompt",
    justification = "Claude print mode needs host credential refresh and runs another agent",
    match = ["claude -p Review this design"],
    not_match = ["claude auth status"],
)
```

- [ ] **Step 3: Verify GREEN**

```bash
python3 -m unittest coding-agents.test_codex_rules.CodexRulesTests.test_prompts_for_claude_print_mode_only
python3 -m unittest coding-agents/test_codex_rules.py
```

Expected: the focused and full rule suites pass.

### Task 4: Provide bubblewrap explicitly on NixOS hosts

**Files:**
- Modify: `nixos/shared/packages/developer-tooling.nix`

- [ ] **Step 1: Add bubblewrap beside the agent harnesses**

```nix
    # agent harnesses
    bubblewrap
    claude-code
```

- [ ] **Step 2: Parse-check the Nix expression**

```bash
nix-instantiate --parse nixos/shared/packages/developer-tooling.nix >/dev/null
```

Expected: exit status 0 with no stderr.

### Task 5: Commit, verify, review, and land

**Files:**
- Verify all files named above plus the design and plan documents.

- [ ] **Step 1: Commit the corrected Codex behavior**

```bash
git add coding-agents/configs/codex/shared.toml coding-agents/configs/codex/rules/default.rules coding-agents/test_merge_codex_config.py coding-agents/test_codex_rules.py docs/superpowers/specs/2026-08-09-codex-cli-auth-design.md docs/superpowers/plans/2026-08-09-codex-cli-auth.md
git commit -m "codex: allow authenticated CLI host access"
```

- [ ] **Step 2: Run integrated verification**

```bash
python3 -m unittest coding-agents/test_codex_rules.py coding-agents/test_merge_codex_config.py
nix-instantiate --parse nixos/shared/packages/developer-tooling.nix >/dev/null
git diff --check origin/master...HEAD
codex execpolicy check --rules coding-agents/configs/codex/rules/default.rules -- gh extension exec example
codex execpolicy check --rules coding-agents/configs/codex/rules/default.rules -- claude -p "Review this design"
```

Expected: eight tests pass, Nix parsing and diff checks are clean, `gh` resolves
to `allow`, and `claude -p` resolves to `prompt`.

- [ ] **Step 3: Inspect branch scope and preserve primary-checkout changes**

```bash
git status --short --branch
git log --oneline --decorate origin/master..HEAD
git diff --stat origin/master...HEAD
```

Expected: only the documented task files differ. Do not update or clean the
primary checkout; its existing `top`, `journalctl`, and untracked files remain
user-owned state.

- [ ] **Step 4: Fetch, rebase, reverify, and push master**

```bash
git fetch origin
git rebase origin/master
git push origin HEAD:master
```

Expected: a fast-forward push after the complete verification suite passes on
the rebased branch.
