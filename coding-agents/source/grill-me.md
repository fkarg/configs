---
description: "Use when the user says 'grill me', wants to stress-test a plan or design, or wants an ongoing research/design workstream with close oversight and small, constrained implementation steps."
mode: skill
---

<!-- Adapted from mattpocock/skills (MIT): skills/productivity/grilling -->

# Grill Me

Run an **ongoing research and design workstream** with close user oversight, using a **decision tree**. Its branches are decisions and their dependencies, **not Git branches**. The main session owns interviewing, architectural overview, and implementation orchestration, with interviewing and architecture first. Keep IC's investigation/planning depth: IC is a mostly autonomous full process taking a single task through exploration, a few manual decisions, implementation, and PR; grill-me continually develops understanding and feeds small, constrained implementation steps. Completing a step does not complete the workstream.

**From the main session, default to using subagents for exploratory tasks and use them broadly for bounded supporting work**: codebase mapping, fact-finding, external research, question generation, planning input, and independent review. Delegate distinct investigations in parallel when independent, rather than doing all exploration in the interactive context. Keep critical reads, synthesis, interviewing, and architectural judgment in the main session; review findings before relying on them. This delegation preference does not change the acceptance gates for implementation.

## Setup and capture

Read applicable repository/session guidance and relevant docs. Resolve the checkout/worktree policy once and record its source. Follow that policy; revisit only if instructions or constraints change. Default to **sequential mode**: accepted implementation steps finish and are reviewed before the next question round. Offer **concurrent mode** when the user's available focus makes independent questions during implementation useful; change modes only on their instruction.

Before questioning, create `docs/brainstorms/YYYY-MM-DD-topic.md` and tell the user its path. Resume an existing capture when continuing the same topic. Keep it as the durable source of truth with:

- Goal/scope, architecture summary, execution mode, checkout policy and source.
- Settled decisions and rationale; facts/evidence separate from recommendations.
- Question backlog with stable Q IDs, prerequisite IDs, and ready/blocked/deferred status.
- Round records: relevant context, session assessment before peer, peer identity/options, merged options, user answers, and material disagreements.
- Implementation proposals with stable P IDs, acceptance, ownership, progress, verification, and commit/PR references.
- Open flags with owners; maintained docs that should receive lasting knowledge.

Checkpoint **after every user reply**, before launching accepted work or preparing another round. Log each answered question separately within that write; preserve partial answers and unanswered questions. Never treat a recommendation, silence, or an ambiguous answer as a decision or kickoff acceptance. Add relevant follow-ups, update dependencies, and explicitly reopen affected decisions if an answer contradicts earlier ones. On resume, read the capture and inspect actual implementation state before continuing.

## Select and prepare rounds

The **frontier** is the set of decisions whose prerequisites are settled. Ask **up to five** mutually independent, topic-related questions per round. Prefer a coherent topic and architectural/high-impact decisions that unblock other work. Keep remaining ready questions in the backlog; never pad a round. A question depending on another unanswered question belongs in a later round.

Finding facts is your job. Read supplied docs and investigate instead of asking the user for information you can obtain. Research or question-generating subagents may add evidence and candidate questions; the main session decides what enters the tree. A running investigation is an unsettled prerequisite: only affected questions wait. If the user cannot answer a decision, record an owned open flag and proceed with independent work; a deferred prerequisite remains unresolved.

## Explore, challenge, and plan

Use the same depth as `ic`, scaled to the task; explain skipped stages rather than silently reducing discovery to a questionnaire. Keep this workflow's manual decision gates, delegation, peer rounds, and resolved checkout policy.

- **Explore:** fan out read-only subsystem exploration and relevant stack specialists. Inspect critical code yourself, including existing tests/workflows. Synthesize entrypoints, data flow, current behavior, constraints, and invariants with evidence/file locations. When claiming functionality is missing upstream, verify the relevant remote state rather than relying on a possibly stale checkout.
- **Research:** for non-trivial discovery, dispatch a separate web-enabled subagent before settling the approach. Ask for current official docs/standards, comparable implementations, alternatives, and failure modes. Require cited findings separating facts from recommendations; give them weight in the design. Skip only genuinely local, mechanical work where outside information cannot affect the answer.
- **Challenge:** distinguish the user's outcomes from a proposed diagnosis or solution. Use an independent premise check; for an uncertain bug cause, use a diagnosis check and run/record the observation that could falsify the leading explanation before designing a fix. A diagnosis check can also challenge the proposed solution when both are uncertain. Look for simpler approaches; bring results into the tree and the next peer-reviewed round. The main session owns peer calls; specialists report to it rather than multiplying cross-model calls.
- **Design:** integrate local exploration and external evidence into alternatives and invariants. Use specialist/simplicity feedback at consequential forks; keep the user's decisions in the interview, with independent peer options and dissent visible.
- **Plan:** turn settled parts of decision branches into small, tightly defined implementation steps; do not bundle an open workstream into one autonomous implementation task. Before offering each P task, record its approach, files/ownership, contracts/invariants, dependency order, behavioral tests/checks, documentation, and change budget (expected touched areas/behavior and non-goals). Proposal acceptance signs off that plan's named scope; surface real open decisions first. If implementation expands the budget or discovers a new architectural tradeoff, pause affected work and bring it back to the interview.

Research and question-generation agents supply candidate questions, not decisions or a separate user interview. Keep their evidence and pending investigations in the capture. Update the architectural overview as decisions settle and implementation returns.

## Prepare the next round

Prepare the next round, **including peer-generated options**, ahead of current answers when relevant independent questions are available and preparation is reasonable. Do not guess current answers or generate speculative conditional rounds. Waiting for answers or implementation to produce better situation-specific questions is fine.

Record each prepared round's prerequisites and relevant factual basis. Immediately before displaying it, revalidate against new answers and implementation findings. Drop out-of-scope questions; rebuild and re-peer materially changed questions/context/options, noting the revision.

## Independent peer before every round

1. Record your own options, tradeoffs, and recommendation **before reading the peer response**.
2. Give the peer the goal, constraints, relevant facts/evidence (including facts against your preference), settled user decisions, and neutral question wording/context. Pending decisions are explicitly unanswered. **Do not send your options, recommendations, predicted answers, or the unfiltered capture file.**
3. Use `peer-review --mode design` with explicitly supplied material via `--stdin` and/or `--file`. Ask the peer to independently generate options, tradeoffs, and a recommendation for each Q ID, challenge framing/dependencies, identify missing alternatives, and name attempted falsifications. The tool returns review-shaped JSON: request Q-ID-labeled sections for options/tradeoffs/recommendations in its `counterproposal` string, with challenges in `findings`. If a question's assessment is missing or unclear, clarify it rather than inventing the peer's view. Follow applicable peer-review routing/auth guidance; wait for the call without invented limits.
4. If the cross-model peer is unavailable, use a fresh-context same-model subagent with the same neutral brief. **Label that fallback**, including the actual answering model when known; report unknown identity rather than guessing. Do not present it as cross-model. If no reviewer is available, report the blocker and ask before presenting an unreviewed round.
5. Read the complete response; recover truncated output before using it. Merge materially equivalent options, preserving meaningful differences and tradeoffs. Highlight both the session's original recommendation and the peer's independently derived recommendation. If new evidence changes your assessment, distinguish that revision from your original view; preserve dissent.

Record each peer result's impact: changed decision, added verification, unique defect, rejected false positive with reason, or no decision impact. An empty attempted-falsifications list is an untested conclusion, not evidence that scrutiny succeeded.

Format each question with sufficient orientation for someone who knows the project's broad structure and mechanisms but not every line:

```text
Q1 — Decision title
Context: component/purpose, current behavior, established constraints, and why this decision matters.
Question: the decision to resolve.
Options: a flexible number of materially distinct choices, each with tradeoffs.
Session: original recommendation and reason.
Peer (answering model; fallback label if applicable): recommendation and reason.
Disagreement/revised assessment: when applicable.
```

Context should explain, not argue for a preferred option. Allow free-text answers or redirection; do not force choices where an open answer fits better. Then list implementation proposals **below the questions** and wait for the user's response.

## Implementation kickoffs

A decision branch is ready for implementation when its scope, contract, prerequisites, and relevant architectural decisions are settled, and no open question or investigation can materially change the task. Do not wait for unrelated decision branches to close.

Offer each ready task as **P1, P2, ...** with scope, settled prerequisites, expected outcome, verification, documentation targets, ownership/checkout, and the repository's operational stopping point. Each proposal needs acceptance; **"P1, P2 ok" suffices**. Choosing an answer to Q1 does not accept P1. Offers may appear without questions when only kickoff decisions remain.

After checkpointing acceptance, delegate the named step and agreed plan to a scoped worker or stack implementer, **not the autonomous `ic` workflow**. The main session retains peer, review, decision, and delivery gates; do not duplicate them in task agents. Include relevant decisions/evidence and boundaries, applicable guidance, resolved checkout policy, and required checks/docs. Tell agents they share the codebase and must preserve others' work. Require them to pause and report partial work and evidence to the main session when scope or architectural decisions reopen. Keep overlapping ownership serial; use isolation or disjoint ownership for concurrent writers only where policy permits. Acceptance does not authorize merging, deployment, or extra scope beyond existing authority.

Review actual changes and verification evidence before building on results. For non-trivial implementation, retain IC's post-green simplicity pass, fresh-context general/pre-mortem review, applicable security/test-quality/performance/consistency specialists, and cross-model diff review. Give reviewers the agreed plan, invariants, diff, and test evidence. Resolve defects, preserve dissent, and rerun affected checks; architectural or budget changes return to the user. Do not call implementation complete with failing required checks or unresolved blocking findings. Include production-readiness review where deployment/operations are affected. Follow through to the accepted repository stopping point; when a PR is in scope, follow CI through fixes to green or report an evidenced out-of-scope failure.

In sequential mode, finish accepted steps and integrate their findings before presenting another ordinary question round; independent research and preparation may run meanwhile. **Exception:** if implementation is blocked on a reopened decision or budget change, pause affected agents and hold the necessary decision round before resuming. Preserve/report partial edits and flag rework. In user-selected concurrent mode, interview on independent questions while implementation runs, keeping the architecture and dependency tree current. Findings that invalidate a settled decision reopen it and return through a peer-reviewed round.

## Workstream checkpoints and knowledge diffusion

At workstream checkpoints, audit the capture for relevant gaps, contradictions, and unresolved prerequisites; route new decisions through normal rounds. Feed each implementation step's evidence back into the architectural overview and decision tree, then continue relevant research/design. Do not close the workstream merely because a P task finished or the current frontier is empty while investigations or dependent decisions remain. An agreed scope is complete when it is understood and remaining deferrals are agreed by the user and explicitly owned; distinguish that scope from the ongoing workstream. Confirm shared understanding before any implementation not covered by accepted proposals or existing explicit authority; do not add repeated confirmation gates for already accepted work.

After implementation and verification, **semi-cleanup primarily means diffusing knowledge**: move lasting what/why, contracts, operating instructions, and important tradeoffs into relevant maintained docs (README, architecture/decision docs, or AGENTS.md where appropriate). Link those docs and implementation references from the capture; brainstorms must not be the sole home of that information.

Usually retain the detailed brainstorm. Before optional removal or substantial pruning of Q&A, ensure the complete notes are committed and recoverable from Git, following repository commit rules. Do not discard unresolved flags or uncommitted detail. Recap decisions, implementation/verification and CI status where applicable, outstanding owners, and where the lasting documentation now lives. Give the user a current architectural map (what changed, contracts/invariants and their coverage, important call paths) and a short reading guide to the changes carrying real judgment.
