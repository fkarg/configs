# Grill Me: Linux browser computer-use for PR-stack QA
Date: 2026-10-18 · Mode: sequential (default) · Checkout: local master, no worktrees (source: repo AGENTS.md "Stay on local master … do not create additional worktrees").

## Goal / scope
~50 agent-authored PRs in 48h. User reviews intent/design fit; wants stronger automatic evidence that the PRs work and nothing regressed in between.
Current practice: batch PRs, deploy locally, test manually. Goal: automate those manual steps via the existing `browser-qa` skill
(`coding-agents/source/browser-qa.md`), which needs a computer-use/browser tool on Linux.
User's proposed solution: Firefox extension providing computer-use control via MCP for allowed/selected tabs.

## Facts / evidence
- Existing design doc: `docs/firefox-browser-mcp.md` (commit 0b468b7, researched 2026-10-14). Firefox-specific, not a general Linux computer-use doc. Leaves bridge transport (loopback WebSocket vs native messaging + Unix socket) open; proposes 5 tools (tabs/open/navigate/observe/act).
- `browser-qa` skill is tool-agnostic: "Use available computer-use/browser tools; if unavailable, prepare cases and report the execution limitation."
- No MCP servers configured in Claude Code on this host (`claude mcp list`, observed); no browser MCP in repo configs (observed).
- Hosts: NixOS + Hyprland (Wayland, Lua config).

## Settled decisions
- D1 (scope, user 2026-10-18): "I mostly need browser/firefox-specific qa, no need for generic computer use actually." Desktop-level Linux computer use (screen capture, OS input, AT-SPI) is out of scope. Still open: whether "Firefox-specific" means Firefox as the engine/the everyday browser, or just browser QA generally (see Q backlog).
- D2 (target browser, user 2026-10-18): "firefox session(s) with me logged in. actually, one with me logged in, and a private window with a second user logged in, to test share permissions and stuff". Agent drives the user's everyday Firefox: normal window = user's identity, private window = second user (cross-user/share-permission tests).
  - Fact to verify: Firefox private windows share one private cookie jar → normal + private gives exactly two identities. Extensions need private-window permission granted per extension. Containers (contextualIdentities) could provide more identities — surface as an option, not assumed.

## Scope additions
- S1 (user 2026-10-18): "much more substantial smoke tests (live use even maybe?) to health-check i.e. demo PR stack deployments but also as release green-blue checks etc". Second use case beyond per-wave browser-qa: repeatable health checks for demo PR stack deploys and release blue/green cutovers. Open: agent-driven vs codified scripts; where it runs (user's Firefox vs unattended/headless in deploy pipeline); relation to D2 (blue/green checks may run without the user's session).

## User policies
- POL1 (user 2026-10-18: "keep in mind that ~/configs is a public repo"): nothing product-/employer-specific (hostnames, accounts, realm names, infra layout, QA results) goes into ~/configs. Scope: this capture and any tool code/docs placed in ~/configs. Applied: product-specific evidence lives in the private companion `~/Coding/infrastructure/docs/brainstorms/2026-10-18-browser-qa-smoke.md` (untracked); this file stays generic.

## Generic facts (observed 2026-10-18, details in private companion)
- Prior real browser QA ran only on macOS via Codex Desktop's built-in browser computer-use against Chrome; its extension connection could not see the private window used for the second account → fell back to OS-level app automation. On Linux, agents had no browser tool; matrices stayed "untested".
- Firefox 157 on this host (NixOS wrapper); several profiles; no dev extensions; no remote/Marionette prefs set. Playwright-cached Firefox 151 + Chromium present; a full Playwright-Firefox launch on NixOS is unverified.
- User's Firefox runs at 120% zoom; Chromium-only visual checks have previously passed layouts that were broken for the user.
- The product repo already has a Playwright "smoke" project with real-IdP login against a deployed URL (never pointed at the local stack).
- No blue/green deploy mechanism exists today; deploy health = container health wait + auto rollback + uptime monitor.
- Codex CLI on this host reports computer_use/browser_use features enabled; Linux functionality unverified.

## Question backlog
(being prepared)

## Round records
(none yet)

## Implementation proposals
(none yet)

## Open flags
(none yet)

## External research (subagent, web, 2026-10-18; sources in transcript — key facts)
- Playwright MCP v0.0.83: `--browser firefox` = Playwright's patched Firefox (Juggler); `moz-firefox` BiDi channel to a stock Firefox exists since v0.0.76 but experimental (driver crash reports). Attach-to-running (`--extension`, CDP) is Chromium-only. Persistent/isolated profiles, storageState, `--allowed-origins` ("not a security boundary"). playwright-cli named sessions per role.
- Playwright cannot attach to an already-running stock Firefox.
- Mozilla `firefox-devtools-mcp` v0.9 (pre-1.0, "not complete"): BiDi via Selenium + Marionette fallback; snapshot/uid click/fill/screenshot/network/console; `--connect-existing` requires Firefox started with `--marionette --remote-debugging-port`; sets navigator.webdriver; warns against leaving it on for daily browsing.
- Firefox remote agent: loopback, no auth (same-user shell = game over by design), Origin/Host checks; CDP removed in Fx141; one BiDi session at a time. Nightly 160 has experimental runtime "remote control for AI assistants" (third-party report only).
- Firefox has no `chrome.debugger` → WebExtension input is `isTrusted=false` dispatchEvent; real-world failures on some frameworks' div-buttons. BiDi input.performActions is trusted.
- Existing Firefox→MCP extensions: all small single-maintainer (foxmcp WebSocket; complynx/ff-mcp native messaging with per-tab grants; others ≤ few stars).
- Claude Code `--chrome` and Chrome DevTools MCP: Chromium only. Codex: Computer Use not available on Linux; built-in browser not in CLI.
- Identities: all private windows share one cookie store; extensions need per-extension "Run in Private Windows"; containers disabled in private windows; containers = N cookie stores in normal windows; BiDi user contexts are implemented as containers.
- Practice: post-deploy/blue-green smoke = codified `@smoke` Playwright specs against green before switch / prod after; no found source gates deploys on agent runs. Agent exploration → findings distilled into deterministic tests (Playwright test agents planner/generator/healer; MCP codegen/recording).
- Unverified: captureTab on private/occluded tabs; whether firefox-devtools-mcp exposes user contexts; moz-firefox channel names.

## Round 1 (prepared 2026-10-18)
Prereqs settled: D1, D2, POL1. Questions: Q1 browser/profile + driver architecture; Q2 identity mechanism; Q3 smoke/health-check strategy (S1).
Deferred backlog: Q4 where tool code/config lives (blocked on Q1); Q5 access boundary details (origin allowlist, write authority — blocked on Q1); Q6 skill changes to browser-qa (blocked on Q1–Q3); Q7 CA trust / NixOS packaging (blocked on Q1).

### Session assessment (recorded before peer)
- Q1 options: (a) custom WebExtension in everyday profile (tab allowlist; untrusted events; build+maintain bridge, transport choice); (b) dedicated persistent Firefox QA profile, stock Firefox, launched with remote flags, driven by existing BiDi MCP (firefox-devtools-mcp / Playwright moz-firefox), visible window; (c) Playwright-launched browser (patched Firefox or Chromium) with per-role storageState, headless or headed; (d) adopt/fork an existing Firefox MCP extension.
  Recommendation: (b). Trusted input, no bridge to build, real Firefox rendering (zoom prefs), everyday logged-in sessions out of reach of page-content injection; user logs in once per identity and it persists. (a)/(d) only if driving the user's literal everyday tabs is a hard requirement.
- Q2 options: normal+private (2 identities; private blocks containers; extension needs private permission); containers in one profile (N identities; = BiDi user contexts; driver support unverified); separate profiles/instances per role. Recommendation: containers in the QA profile, falling back to two profile instances if the driver can't target containers.
- Q3 options: codified @smoke Playwright specs (extend existing smoke project) run post-deploy against the stack; agent-driven health runs as gate; hybrid (agent explores, findings distilled to specs; specs gate). Recommendation: hybrid, with only codified specs gating; run locally after deploy first, CI/deploy-hook later. Clarify "blue/green" (no mechanism exists).

### Peer r1 (codex, gpt-6.1-sol; review c8354c58718c487a8f381280616bb395) — Firefox-framed brief
- Q1: dedicated stock-Firefox QA profile + Mozilla firefox-devtools-mcp, adoption conditional on an end-to-end spike (both identities targetable, OIDC, trusted input, screenshots, 120% zoom). = session rec; ADDED VERIFICATION (spike gate). Notes remote control ≠ selected-tab authority (profile separation reduces exposed state, no per-tab boundary).
- Q2: DISAGREES with session: keep literal D2 normal+private; don't pick containers just because BiDi exposes them. Session's container rec changes the settled D2 → must be asked, not assumed. (Valid: session was about to re-open D2 silently.)
- Q3: agrees with hybrid; adds: product assertions stay in product repo; no new automatic rollback triggers without a separate decision; Q3 independent of Q1/Q2; blue/green is a future mechanism — pre-switch + post-switch smoke once it exists.
- Falsifications listed (9). Impact: added verification (spike gate), unique point (D2 re-open must be explicit), no change to Q3.

### User mid-round input (2026-10-18)
- "I mean if it helps I also have chrome & chromium installed, if you think that's a better/cleaner target than firefox". Re-opens the Firefox part of D1/D2 as an option, not a decision. Q1/Q2 materially changed → re-research Chrome specifics, rebuild + re-peer. Added Q4: which engine should QA match (customer browsers vs developer's daily browser).

### Chrome research (subagent, web + local experiments on this host with Chromium 154 under Xvfb, chrome-devtools-mcp 1.11.0; 2026-10-18)
- [obs] chrome-devtools-mcp attached to a running Chromium sees and can click in a human-opened incognito window and in a tab from a second Chrome profile of the same browser process. Clicks are isTrusted=true.
- [src/obs] `new_page isolatedContext:"name"` = CDP browser context (cookie-isolated, incognito-like), works when attached to an existing browser, survives MCP server restart, lost on browser restart.
- [src] `--autoConnect` (Chrome 144+, consent dialog per connection, reads DevToolsActivePort; Chromium needs `--userDataDir ~/.config/chromium`). Chrome 136+: `--remote-debugging-port` ignored for the default user-data-dir → dedicated QA browser needs its own `--user-data-dir`; then `--browserUrl` connects without consent prompts. Remote debugging port = unauthenticated loopback (same-user processes can drive it).
- [src] Playwright MCP: own-launched browser has one context per server instance (two identities = two server instances with per-role storage state); `--extension` = one picked tab group per client, incognito unverified.
- [src/sec] Claude in Chrome: Claude-only, needs Anthropic plan login, incognito on Linux reported failing (closed not planned). Extension-based tools are weak for two simultaneous identities.
- [inf] The macOS Codex incognito failure was a limitation of that extension, not of Chrome/CDP.
- NixOS: no /opt/google/chrome; pass executable path; Playwright-downloaded browsers need nixpkgs playwright-driver.browsers or system executable.
- Unverified: autoConnect consent flow here; internal-CA trust with a custom user-data-dir; agent creating pages inside a non-default profile.

### Session assessment, rebuilt Q1/Q2 + new Q4 (recorded before peer r1b)
- Q1 rec: dedicated, visible, long-lived QA Chrome/Chromium (own user-data-dir, remote-debugging-port on loopback), driven by chrome-devtools-mcp `--browserUrl`; one browser shared by whichever CLI runs QA. Alternatives: autoConnect into an everyday Chrome (consent per connection); Firefox QA profile + firefox-devtools-mcp; custom Firefox extension; Playwright MCP-launched browsers (best for headless/repeatable, weaker for "me logged in").
- Q2 rec: user in the QA browser's default context (persistent login); second user in a second Chrome profile of the same QA browser (persistent across restarts) — fallback to incognito window (literal D2, verified reachable) or agent-created isolatedContext (re-login after browser restart). Spike must verify agent can open/target pages in the second profile.
- Q4 rec: agent QA on Chromium; Firefox fidelity via a Firefox project in the codified smoke suite — final answer depends on customers' browsers (user knowledge).
- Assumption (stated, not asked): the user logs identities in manually; agents never handle passwords.

### Peer r1b (codex, gpt-6.1-sol; review 2f88ae9cf66e422ebe9887f11e1ab22e)
- Q1: same as session (dedicated Chromium QA instance + chrome-devtools-mcp --browserUrl), gated on end-to-end validation (CA, both logins, targeting, page creation, MCP + browser restart recovery). One active agent operator per QA instance. Dedicated instance is an operating convention, not an authorization boundary. Impact: added verification.
- Q2: DIFFERS: literal incognito window first (verified reachable), session-lived second login; persistent second profile only if persistence matters and after validation. Verify the application-visible account before every identity-sensitive action (unique point → goes into skill).
- Q4: Chromium for agent QA, labeled as such; Firefox evidence where layout claims need it. Superseded by user D3.
- Falsifications: 8 listed.

## D3 (engine, user 2026-10-18)
"we have both firefox & chrome-ish users, my understanding is that firefox is the trickier one to get right, but I wouldn't mind having the automation for chrome only and then I can do additional checks in firefox, that'd be fine". → Agent automation targets Chrome/Chromium only; user does supplementary Firefox checks. Resolves Q4. Firefox extension / Firefox BiDi options dropped from Q1. docs/firefox-browser-mcp.md becomes historical (flag: mark superseded during cleanup).
User also asked why not an extension → explained in round 1 text.

## Round 1 presented (2026-10-18): Q1, Q2, Q3; proposals P1 (CDP spike), P2 (existing smoke suite vs local stack).

### Round 1 answers (user, 2026-10-18)
- Q1 → D4: "A is fine, I have (somewhat) sufficient albeit not infinite RAM available. D would also be fine if you were to prefer it." Dedicated long-lived QA Chromium + chrome-devtools-mcp over loopback debug port. Playwright-launched (D) acceptable alternative. Internal CA exists (path in private companion), "not in system trust store though maybe something to look into" → open flag F1 (CA trust strategy: QA-profile-scoped vs user NSS DB vs NixOS system trust; public-repo constraint applies).
- Q2 → D5: "B, depending on how strong profile isolation actually is (and if it works on nixos now, I believe it didn't properly sometime in the past); falling back to A. second login is cheap after restarts, first (my) login is not so cheap, and should (partially) survive restarts ideally." Second Chrome profile, verified in P1; fallback incognito. Requirement: primary login persists across restarts (suspect: Linux cookie encryption/keyring → test --password-store=basic).
- Q3 → D6: "let's create the smoke test(s) first before specifying all later use cases. I mostly expect to run them locally on a new PR stack to ensure 'nothing fundamentally broke' and 'most previous things continue to work'." Pipeline/blue-green deferred.
- POL2: "ideally agents shouldn't handle passwords." Scope: QA browser logins and smoke-test credentials. Applied: user logs in manually in QA browser; smoke credentials consumed from a user-created env file the agent never reads.
- P1, P2 accepted ("go ahead with P1 and P2"). User expects P2 to fail (first run since creation) and doesn't know what the suite covers → P2 output must explain coverage.
- Execution note: P1 needs the user's manual logins → main session runs P1 interactively (subagents can't pause for the user). P2 code reading/launch prep delegated; actual credentialed run after user creates the env file.

### P1 progress (main session)
- QA browser: chromium 154 (NixOS wrapper), `--user-data-dir=~/.local/share/qa-chromium --remote-debugging-port=9222 --password-store=basic --ignore-certificate-errors-spki-list=<sha256 SPKI>`; port bound 127.0.0.1 only (observed `ss`).
- TLS (F1): CA is unconstrained (no nameConstraints) and its private key sits next to it in the checkout → adding it to user NSS DB/system trust would let anything reading that key MITM every site for this user. Browser-scoped SPKI pin chosen for the spike. Observed: CA-SPKI alone fails because the server presents only the leaf (chain length 1); leaf SPKI works. Robust alternative: serve the full chain, then pin the CA SPKI.
- chrome-devtools-mcp 1.11.0 via `--browserUrl` connects; telemetry defaults ON (usage statistics, CrUX) → use `--no-usage-statistics --no-performance-crux`. Spike driver: MCP inspector CLI (one server process per call).
- Reached Keycloak login page through MCP (observed).
- POL3 (user 2026-10-18): "small costs for a smoke test is fine. in fact, I'd like to add a couple of things later that will cause some more (small) costs, but no other way to confirm the full stack is working properly". Scope: smoke tests on local PR stacks may make small paid provider calls. (Private companion records the product specifics.)
- P1: QA Chromium shows "unsupported command-line flag … Stability and security will suffer" infobar for the SPKI flag (cosmetic; expected). Alternative without the flag: HOME-scoped NSS DB (as P2 uses) — but HOME override also redirects fontconfig/GTK config; untested. User logged in as primary in default profile.
- P1 observed: MCP snapshot shows logged-in account name in the sidebar (identity check feasible from a11y snapshot). Two `chromium --user-data-dir=X` launches while one runs just open a tab in the running instance (singleton) — restart scripts must wait for the main process to exit.
- P1 observed: primary login did NOT survive a graceful browser restart (SIGTERM). Cookie metadata (no values): only the IdP's persistent session cookie was stored (10h max lifespan); the IdP identity cookie is a session cookie (IdP "remember me" not enabled) and is dropped on browser close. Not a keyring/NixOS problem. Options: (a) browser session restore (`--restore-last-session` / "continue where you left off") restores session cookies, bounded by IdP idle/max lifespan; (b) enable IdP remember-me on the local realm (product config change).

### P1 results (observed 2026-10-18, chrome-devtools-mcp 1.11.0 via persistent MCP SDK client + Chromium 154)
- Two Chrome profiles in one QA user-data-dir hold two different app identities on the same origin at once (sidebar account differs per tab) → cookie isolation between profiles works on NixOS.
- Agent can drive the second profile's existing tab: navigate_page, a11y snapshot, click by uid (isTrusted=true, verified with a capture listener), fill (value set + app filter reacted), screenshot to file. Second user saw the template shared by the primary user → sharing scenario observable.
- Limitation: new tabs can only be created in the default profile (CDP Target.createTarget with the second profile's browserContextId → "Failed to find browser context"; profile contexts aren't CDP-managed). chrome-devtools-mcp new_page likewise only default/isolatedContext. Workaround: keep one long-lived tab per non-default profile and navigate it. D5 (B) stands with that constraint.
- pageIds are per-MCP-server-process positional; identity must be checked via snapshot (account link), not page number — confirms peer rule.
- Page list URLs can include OIDC redirect fragments (code/state) → transient auth codes land in agent transcripts; one-time use, low risk; note for skill.
- Login persistence: user reports primary (IdP-broker) login survived a restart (user observation; mechanism inferred: IdP-broker SSO cookie re-establishes the session). Primary-requirement satisfied.
- Cert: user wants the SPKI-flag infobar gone. Chrome's chrome://certificate-manager "Custom" certs are per-profile (stored in the profile's ServerCertificate DB, not ~/.pki/nssdb) per Arch Wiki (secondary, updated ~2026-09) → import CA in both QA profiles, relaunch without flag, verify. Not doable via MCP (native file picker).
- F1 update (user 2026-10-18): auto-import every internal CA cert from the product infra checkout (paraphrased: product-specific path) → system trust store, host-local (not public repo). Agent's edit of /etc/nixos/configuration.nix was denied by the auto-mode classifier (TLS/auth weakening) → handed to user with snippet. Backlog: name-constrain local CAs (infra change, colleague impact). A host-local file-permission issue was flagged to the user (details not recorded here).
- User 2026-10-18: CA system-trust snippet applied by user ("reasonable block, I've added it"), effective after next rebuild+reboot. Smoke account: "smoke test account should be primary".
- P2 execution choice (main session, under POL2): primary logs in via an external IdP broker (MFA likely) → scripted password login is a poor fit and would put a real-account password in a file. Instead seed the suite's storageState from the QA browser's default profile: export only app-domain cookies via CDP to the gitignored storage-state path (mode 600, values never printed), run `smoke` with --no-deps, delete afterwards. No smoke.env needed.
- P2 done (details private): existing smoke suite runs on this host with the QA-browser session seeding + scoped NSS trust; 9/10 pass, 1 race-flaky test (passes alone); two test-quality issues. Seeding storageState from the QA browser avoids passwords entirely (POL2) and works with an MFA'd IdP broker.
- User 2026-10-18: "so would we be ready? do we need adjustments to the browser-qa skill (for linux)?" → round 2.

## Round 2 (prepared 2026-10-18)
Gaps to "ready": MCP server not registered in any harness; no launcher for the QA browser; browser-qa skill lacks Linux/QA-browser operating rules; smoke suite has one race-flaky test + two quality issues and no runner.
### Session assessment (before peer)
- Q8 MCP registration scope: (a) all four harnesses globally via coding_agents role (generic, public repo); (b) Claude-only user scope; (c) per-project config in product repos (private). Rec: (a) but keep it off by default? → rec (a) global, since QA sessions run from varying cwd; cost = ~30 extra tool schemas in every session context. Alternative: register under the skill only (not possible portably).
- Q9 QA browser lifecycle: (a) launcher script in configs/scripts (start/restart/wait-for-exit, generic flags, no product data); (b) systemd user service always on; (c) agent launches on demand. Rec (a), skill calls it if the port is down.
- Q10 skill changes: Linux section (QA browser + chrome-devtools-mcp), identity verification rule, one driver at a time, one long-lived tab per extra profile, Chromium-only labeling with Firefox left to user, no OIDC fragments in reports, run product smoke baseline first when a repo provides one; product role→profile mapping and URLs live in private repo docs. Rec: do it; no real question except whether smoke baseline is a mandatory first step.
- Q11 smoke suite next: fix race (wait for model readiness), make sidebar assertion target the created chat, cleanup or label smoke chats, add a runner that seeds storageState from the QA browser; then extend coverage with user-prioritized "previous things". Needs user's priority list of flows.
### Peer r2 (codex gpt-6.1-sol; review 80524050e08c40a7a26c15f1b01a1fd6) — impacts
- Q8: DIFFERS: managed workstation-local registration only for harnesses actually used for QA, activation scoped to QA work where possible; telemetry off; pin spiked version. Session rec was global all-four → asked.
- Q9: agrees (explicit launcher, keep running); adds: never silently kill/replace an existing browser; re-enumerate pages + verify identity after any reconnect; user reopens a lost second-profile tab. Added verification.
- Q10: agrees public-generic + private-product split; UNIQUE: remove product repo names already in the public skill (POL1 consistency) → asked; drive the second profile's existing tab instead of "private session" advice; cookie export as a local helper, never agent-transcribed.
- Q11: repair-before-grow; serial workers; keep readiness fix even if serialization hides it; repeat full suite to establish baseline; real-account data ownership: scoped cleanup or explicit limitation (UNIQUE, asked); coverage priorities from the user + escaped regressions.
- 9 falsifications listed.

### Round 2 answers (user, 2026-10-18)
- Q8 → D7: "only codex + claude, and ideally only on demand (i.e. the qa skill) - most sessions won't need a browser mcp at all." Mechanism for skill-scoped MCP activation = research item R1 (Claude subagent/skill-scoped MCP, Codex agent/profile-scoped MCP, generator support).
- Q9 → D8: A (explicit `qa-browser` launcher, generic, ~/configs/scripts; never kills/replaces a running instance silently).
- Q10 → D9: "repo names/some paths are fine, in particular since it's already there." Keep existing product repo names in the public skill; still no hostnames/accounts/realms/results (POL1 narrowed accordingly).
- Q11 → D10: repair-first agreed; cleanup (a) delete exactly the chats the previous run created, fallback (b) prefix+accumulate; "can we do cleanup _on next startup_ so that I can always see the (results) of the most recent run?" → cleanup of run N's records happens at the start of run N+1.
- Coverage priorities + model/cost defaults → private companion (product-specific). Expansion = future P6 (needs fixtures/design), not part of P5.
- P3, P4, P5 accepted ("go ahead P3 P4 P5").

### Implementation plans (recorded before launch)
- P5 (simplified location, stated to user): ONE PR in the product frontend repo containing test fixes (model-readiness wait, sidebar asserts the created chat, serial workers for smoke), cleanup-on-next-startup of previously created records (IDs recorded in a gitignored state file; delete via supported API/UI; fallback prefix+accumulate), and a local runner that seeds storageState from the QA browser's default profile over CDP (app-domain cookies only, mode 600, never printed), checks stack health/version + auth first, runs serially, prints a clear result. Replaces "helper in configs + runner in infra" — keeps product tooling in the product repo and avoids a cross-repo dependency on a personal script. Invariants: no credential values in output/logs/artifacts; no OIDC fragments in reports; never delete records the run didn't create. Verification: full suite ≥3 consecutive green runs against the local stack, cleanup observed. Ownership: frontend-expert worker, worktree per repo convention (concurrent sessions on this machine), PR + CI to green, no merge. Budget: tests/smoke/*, playwright config smoke projects, one runner script, package.json script, README section, .gitignore. Non-goals: new coverage flows (P6), CI workflow changes.
- P3 (blocked on R1 for registration part): `scripts/qa-browser` launcher (start-or-attach, port/profile defaults, passthrough args, wait for main-process exit on restart, never kill silently); MCP registration for Claude + Codex scoped to QA per R1. Main session authors.
- P4 (after R1): browser-qa skill update per Q10 list + how browser tools become available; private QA notes in infra docs (uncommitted). Main session authors.

### R1 result (research subagent; Claude Code 2.1.283, codex-cli 0.163.0)
- Claude: subagent frontmatter `mcpServers` supports inline server definitions, connected only while the subagent runs, invisible to the main conversation [doc]. Skills can't declare MCP. Subagents lose AskUserQuestion. MCP tool search (deferred schemas) is on by default but OFF when ANTHROPIC_BASE_URL is non-first-party (claudex) [doc+inferred]; global registration still spawns the server in every session. `--mcp-config` (+ optional --strict) gives per-launch control.
- Codex: custom agents cannot carry mcp_servers (ignored; parent config only) [doc+source]. Profiles: `codex -p qa` overlays ~/.codex/qa.config.toml [observed --help + doc]. Skill `dependencies.tools` type mcp → prompts to install permanently into global config (feature on by default) — avoid. MCP tools always deferred when tool_search available.
- Generator: frontmatter parser handles scalars/nested maps only; unknown keys dropped with warning. Claude MCP servers live in ~/.claude.json, not the curated settings.json.
- SIDE FINDING (unique defect, out of scope, flagged to user): generator emits `sandbox_mode = "read-only"` in Codex agent files for edit:deny agents, which current Codex ignores → Codex reviewer agents not actually read-only (doc + main-branch source; unverified against 0.163.0 tag).
- Unverified: resumed Claude subagent reconnecting its inline server; whether a Claude agent `tools:` allowlist must list inline MCP tools; whether Codex rewrites profile files.

## Round 3 (prepared): Q12 activation mechanism
### Session assessment (before peer)
Options: (A) Claude: browser-qa skill (main thread) + new `browser-qa-driver` subagent with inline mcpServers (generator `mcp:` key); Codex: `-p browser-qa` profile. (B) Per-launch for both: tracked server config; start QA sessions with `claude --mcp-config <file>` / `codex -p browser-qa`; skill checks tools and tells user how to relaunch if missing; no generator change. (C) Global registration relying on deferred tool schemas (fails under claudex; server spawns everywhere). (D) `context: fork` skill-as-subagent (loses main-thread interaction).
Rec: B — simplest, symmetric across both harnesses, main thread keeps direct browser + user interaction; cost: QA sessions must be launched deliberately (a one-word wrapper/alias can hide it). A is closer to "the skill turns it on" for Claude only, at the cost of generator work and a driver/skill split.
### Peer r3 (codex gpt-6.1-sol; review 625300eaffe94aeb80b0987549271c0a)
- Same as session rec (explicit QA launch in both; skill stays main-thread; skill hands off with relaunch command when tools are missing). Codex variant differs: `enabled=false` in shared layer + `-c mcp_servers.x.enabled=true` instead of a profile file (one fewer artifact; avoids unverified profile-file rewrite). Unique framing point: "on demand" = QA-session scope, not skill-duration scope — must say so to the user. Worker-subagent option kept as alternative pending resume/reconnect checks. 7 falsifications (reasoning only). Impact: refined Codex mechanism; added verification (ordinary launch starts no browser MCP process).
## Round 3 presented: Q12.
### Round 3 answer (user 2026-10-18)
- Q12 → D11: "small wrapper (codex-qa / claude-qa) sounds good actually, and I won't have to remember massive config flags". Option A, QA-session scope, wrappers `claude-qa`/`codex-qa`. Implementation choice: define the server per launch in the wrappers (Claude `--mcp-config <json string>`, Codex `-c mcp_servers.chrome_devtools.*`) → no entry in any global/shared config at all; wrappers also `qa-browser start` (attach or launch).

### P3/P4 delivered (commit 8951cd7 on configs master)
- scripts/qa-browser (start-or-attach, status, stop, restart; owner pid from the profile lock verified against /proc cmdline (dir + port) after cross-model review found stale-lock pid reuse and port-collision attach risks), scripts/claude-qa (+ codex-qa symlink; server defined per launch only), Ansible links (applied on jolly: ok, 0 failed), browser-qa skill "Browser control" section. Verified: codex-qa mcp list shows chrome_devtools, plain codex none; claude-qa -p called list_pages, plain claude reports no MCP servers; launcher tests incl. refusal on port collision.
- Peer diff-review (codex gpt-6.1-sol): 2 must (stale lock pid kill; foreign browser on port) → fixed; 2 nits → taken.
- Private notes: ~/Coding/infrastructure/docs/qa-browser.md (untracked).

### P5 status
- Implemented + verified locally by worker (commit ba13ecac in frontend-react worktree `.worktrees/fkarg-smoke-local-runner`): 3 consecutive green runs (12/12), cleanup of previous run's chats observed, artifact scan clean, tc/lint/unit OK. Model: "GPT-6 Luna" (no "6.1 Luna" exists; SMOKE_MODEL overridable). Worker ran its own codex diff-review (e4a7cbed6acf41e98ed5ad43d04926de): 2 defects fixed.
- BLOCKED: repo rule changed today (issue-number branch names, GitHub ruleset enforced); `gh issue create` denied by auto-mode classifier as external write → user action needed. Fresh reviewer + security reviewer running.
- Open observations for PR text: app allows send while models load; model pick updates recently-used models; CI smoke.yml has no SMOKE_MODEL and its trace-on-first-retry can upload session tokens on failure (pre-existing).
- P5 reviews: general reviewer "ready to ship" + 3 should-fix (record key ≠ cleanup key on redirects; state not keyed by account; CI now requires the named model); security reviewer: no exploitable issues, should-fix `--ui` re-enables traces with bearer tokens (observed in Playwright source), nits (same-origin bearer capture, id validation, .dockerignore, wording). Decisions (main session, within P5 budget): record under baseURL origin; cleanup warns instead of gating the suite; model selected only when SMOKE_MODEL set, runner defaults it → CI semantics unchanged, no workflow change; reject --ui; README notes on account mixing/concurrency. Sent to worker as a follow-up commit; push still waits on the issue.
- P5 follow-up commit e2485213 (all 8 review fixes); 2 consecutive green runs (12/12), malformed-id drop and 404 handling observed, --ui rejected, bad CDP endpoint fails cleanly, password path order intact. Two warning paths (token timeout, non-2xx/404 delete) not exercised live. Not pushed: waiting for issue.

## State at checkpoint (2026-10-18)
- Issue frontend-react#1206 created (user: "go ahead."), branch renamed to `1206-smoke-local-runner`, PR frontend-react#1207 opened (not merging). CI: watching.
- Lasting docs: script headers (qa-browser, claude-qa), browser-qa skill "Browser control", docs/firefox-browser-mcp.md superseded note (what/why), product notes in the private infra repo (docs/qa-browser.md, untracked), frontend README smoke section (in PR).

### Architecture map
QA session: `claude-qa`/`codex-qa` → `qa-browser start` (attach or launch dedicated Chromium, own user-data-dir, 127.0.0.1:9222) → harness started with chrome-devtools-mcp defined for that session only → browser-qa skill drives profiles (Default = primary role, second profile = second role; new tabs only in Default; identity verified from page snapshot before identity-sensitive steps).
Smoke baseline: `pnpm test:smoke:local` (product repo) → healthcheck → CDP cookie export from the QA browser's Default profile (app host + subdomains, mode 600) → setup verifies session → cleanup deletes previous run's recorded chats (non-gating) → smoke tests serially with opt-in model.

### Open flags / backlog (owners)
- F1b (user): reboot to activate system CA trust; then relaunch QA browser without the SPKI flag (`qa-browser restart`). Hardening: name-constrained local CAs (infra, colleague impact) — backlog.
- F2 (user): Codex generator emits `sandbox_mode` in agent files, which Codex ignores → Codex "read-only" agents may not be read-only. Separate session.
- F3 (user/product): app allows send while models load (noted in PR #1207).
- P6 (next proposal, needs design): expand smoke coverage per user's priority flows (private companion); requires fixtures (connector ingest), cost bounds, second-identity strategy for sharing checks in Playwright.
- First real browser-qa wave with claude-qa/codex-qa not yet run — the true end-to-end check of P3/P4.
