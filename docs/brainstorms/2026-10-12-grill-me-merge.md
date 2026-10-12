# Grill Me: merged workflow
Date: 2026-10-12 · Goal: merge the two interview skills and fit the user's development workflows.

## Summary / settled requirements
- Keep dependency-tree/frontier mechanics. Ask up to five independent questions per round, with a flexible number of options.
- Persist in docs/brainstorms/YYYY-MM-DD-topic.md; perform some cleanup after implementation.
- Give enough context before each question for a reader who knows the project's broad structure and mechanisms.
- Highlight the current session's assessment and an independent peer opinion. Ask the peer before presenting each round.
- Offer subagent implementation kickoff between rounds for sufficiently settled work.
- Decide checkout/worktree strategy once from repository and session guidance.
- Canonical source is coding-agents/source/grill-me.md (mode: skill). The second source was initially untracked, was preserved in commit 3a4b289, and is now removed from the working tree. Preserve unrelated checkout changes.
- Peer derives options from shared facts/conditions and neutral questions; never send pre-selected session options. Session merges materially equivalent options and states tradeoffs.
- Kickoff proposals go below the questions with stable P identifiers. Acceptance is required each time; a brief response such as "P1, P2 ok" is sufficient.
- Cleanup primarily diffuses lasting what/why information into relevant maintained docs. Usually retain detailed brainstorms; they must be recoverable from Git before removal. Do not make brainstorms the sole home of implementation knowledge.
- Fresh-context same-model fallback is acceptable and must be clearly identified.
- Checkout strategy for this task: local master, no worktrees, from repository AGENTS.md. The merged skill resolves strategy once per session from applicable guidance, and revisits only when guidance/constraints change.

## Decision tree / question backlog
- [x] Q1: peer independently generates options; main session merges equivalent options with tradeoffs.
- [x] Q2: proposals below questions, accepted individually by P identifier.
- [x] Q3: diffuse lasting knowledge into relevant docs; retain notes by default and Git history before removal.
- [x] Q4: clearly labeled fresh-context same-model fallback.
- [x] Q5: finish accepted implementation before next round by default; explicit concurrent mode allows independent questions during implementation.
- [x] Q6: prepare independent, topic-related questions ahead where possible/reasonable; wait for situation-specific questions when dependent answers or implementation would improve them.
- Delivered scope: merged canonical skill, duplicate removal, maintained documentation, generation/validation and realistic workflow checks. No orphaned duplicate installation was found.

## Q&A log
### Initial requirements
- Captured: frontier rounds, up to five questions, flexible options, context first, two highlighted assessments, peer before each round, durable capture, partial implementation offers, checkout policy chosen once.
- Distinction: upstream-first handling and frontier mechanics share dependency ordering; the frontier batches independent decisions.

### Round 1 answers
- Q1: "peer should generate own options based on facts/conditions, not receive pre-selected ones"; merge basically-same options and list tradeoffs.
- Q2: "kick-off proposals below questions"; acceptance each time, "P1, P2 ok" suffices.
- Q3: "mostly diffusing the Q&A notes into other docs where relevant"; notes fully retrievable from git history; probably mostly retained; what and why must not exist only in brainstorms.
- Q4: "fallback to fresh-context same-model, but that needs to be noted."
- User answers settle the workflow tradeoffs. Remaining task is authoring and verification, not another mandatory approval round.

### Round 2 answer / expanded requirements
- Q5: default is implementation steps finish before the next question round. Add an explicit concurrent-mode option for open questions during implementation; mode depends on the user's available focus.
- Main interactive session primarily interviews and maintains the architectural overview; it also orchestrates implementation.
- Main session may delegate research and future-question generation, then select questions for later rounds.
- User wants the next round fixed, including peer options, before answering the previous round.
- "Branches" means decision branches, not Git branches. Distinguish checkout/Git terminology explicitly.
- Q5's default is settled. Mode selection can be session-level and changed by user; question-preparation dependency boundary remains to clarify.

### Round 3 answer
- Q6: "prepare independent questions ahead", "prepared ahead where possible/reasonable", and "topic-related".
- User prefers related questions and accepts waiting for better situation-specific questions, particularly with sequential implementation as the default.
- No artificial queue filling, speculative answer combinations, or mandatory advance round when no relevant independent questions are ready.

### Final scope clarification
- User: "grill-me should still have the full exploration, research and planning (subagentic) approach as the IC skill/approach" with "more tightly manual involvement"; IC is for already-defined, less-open/more-autonomous tasks.
- Preserve IC's investigation/research/premise/design/plan/review/delivery depth; the difference is interaction and decision authority, not research quality. Do not inherit conflicting IC-specific worktree rules, authorship assumptions, or peer-call quotas.
- Accepted task plans carry explicit invariants, file ownership, verification/docs, change budget, and operational stopping point. Architectural/budget changes return to the interview. Appropriate review and CI followthrough remain part of orchestration.
- Further user clarification: IC is a mostly autonomous single-task full process (exploration, few manual decisions, implementation and PR). Grill-me is an ongoing high-oversight workstream of substantial research/design and substantially smaller, constrained/defined implementation steps. Step completion feeds the workstream rather than closing it or bundling it into an IC task.
- Follow-up: default to subagents for exploratory tasks, and use them more broadly from the main session. Added an explicit preference for bounded exploration/research/question-generation/planning-input/review delegations, parallel where independent, while main retains critical reads, synthesis, interviewing, and architectural judgment. Implementation acceptance gates still apply.

## Peer reviews
- Round 1 peer: Claude Opus 5.5 (claude-opus-5-5), supplied source texts and user requirements without session recommendations. Complete JSON read; peer cache save failed with PermissionError, so material findings are recorded here.
- Added verification: record session recommendations before reading peer output in future rounds; require neutral contexts and explicit attacks on framing. This round did not record session recommendations in advance, so it is not a demonstration of that ordering.
- Unique defects: literal merges conflict on checkpoint granularity, whole-session implementation gate, fixed options, and whole-frontier size. Rewrite each explicitly.
- Added verification: ready tasks need settled dependencies, explicit scope, acceptance consistent with prior authorization, and disjoint ownership or serial execution in shared checkouts.
- No decision impact: cap/prioritize frontier; resolve checkout policy once; label fallback family/model and await running peers without invented time limits.
- Rejected false positive: peer suspected mode: skill did not render skills. build.py lines 331-338 explicitly support it; preserve mode: skill.
- Disagreement to present: peer proposes supplying neutral options to align its assessments; session prefers shared facts and neutral questions, with peer deriving its own options to reduce anchoring.
- Cleanup recommendation: condense notes once implementation is verified, keeping decisions/rationale, divergences, flags/owners, and commit/PR references; do not delete the only durable record.
- Peer failure recommendation: try prescribed host auth retry where relevant, then fresh-context fallback; if no review can be obtained, ask user before proceeding without one.
- Round 2 peer: Claude Opus 5.5 (claude-opus-5-5), given only settled user requirements and raw environment facts. Complete JSON read. No further decision recommended by peer; most mechanics independently matched the session's assessment.
- Added verification: notes must be committed before optional removal. The untracked duplicate skill also needs its content preserved before removal; checkpoint its original content in Git before consolidation.
- No decision impact: mode: skill, filename identity, five-question overflow prioritization, pre-peer session assessment, neutral conditions, per-message checkpoints, documentation diffusion.
- Material divergence: peer recommends finishing accepted tasks between rounds before the interview resumes, to avoid later answers invalidating implementation. Session favors continuing unrelated rounds if the task is isolated/file-disjoint and all its decisions are settled; otherwise serialize. This timing choice has a real latency/coordination tradeoff, so surface it despite the peer treating serialization as a default.
- Round 3 peer: Claude Opus 5.5 (claude-opus-5-5), supplied settled requirements and the user's new wording without session options/recommendations. Complete JSON read.
- Unique defect: an unconditional fixed-next-round requirement conflicts with the settled-frontier rule for a chain or exhausted independent frontier. Surface a fallback choice rather than guess prerequisites.
- Added verification: a prepared question's dependency IDs and relevant factual basis must be rechecked immediately before presentation, after answers and sequential implementation. Changed scope drops questions; changed material context/options requires fresh peer review and an explicit revision marker.
- Divergence: peer prioritizes useful research/open questions to fill an empty preparation buffer, then synchronous preparation; allows limited conditional preparation. Session prioritizes relevance over keeping the buffer nonempty and rejects automatic conditional combinatorics or filler questions.
- Rejected as inapplicable: claimed roughly doubled round count only follows a rigid pipeline without synchronous fallback; do not impose that lag or invent a minimum round size.

## Round 3 — original assessments, now answered
- Q6: Does "fixed in advance" mean prepared when independent questions exist, with visible revision/review when facts change and just-in-time preparation when the ready set is exhausted, or conditional pre-reviewed variants for anticipated answers?
- Session: independent prepare-ahead, no padding or predicted answers; revalidate and re-peer changes; synchronous preparation when necessary.
- Peer: independent prepare-ahead with fact-basis revalidation; draw on useful broader open/research questions before waiting; limited conditional variants can be an optional exception.

## Round 2 — original assessments, now answered
- Q5 context: accepted tasks have settled contracts; isolation or disjoint ownership is needed for concurrent edits. Future questions may be independent of the task, but implementation findings could require rework or alter the frontier.
- Session: allow overlap only for independent questions and an isolated or file-disjoint task; checkpoint implementation findings and pause affected work if a settled decision reopens.
- Peer (Claude Opus 5.5): complete accepted tasks before presenting the next round; simpler coordination but longer pauses in the interview.
- Options: overlap independent work (lower latency, more coordination); wait for completion (simpler coordination, pauses the interview).

## Session assessment before round 3 peer
- Always call them decision branches; use checkout/worktree/Git branch only for repository state.
- Default sequential execution; concurrent mode explicit and changeable, with only independent questions and isolated/file-disjoint tasks overlapping.
- Prefer prepare-ahead for independent ready questions only. Do not speculate on unanswered prerequisite decisions. Newly unblocked questions require preparation and independent peer review after those answers arrive.
- A prepared round must be revalidated if an answer changes facts or prerequisites; materially changed context/questions/options require fresh peer review before display.
- Alternative interpretation is conditional pre-reviewed rounds for anticipated answer combinations, which adds speculative work and expands the capture. This is a genuine tradeoff to surface rather than silently choosing.

## Round 1 — original assessments, now answered
- Q1: peer input — session favors facts and neutral questions without session options/recommendations; peer favors neutral questions/options with framing challenge, no session recommendation.
- Q2: kickoff — session and peer favor an explicit scoped offer when open decisions cannot affect the task, launched after acceptance unless prior authorization already covers it.
- Q3: cleanup — session and peer favor condensing in place after verified implementation, preserving decision rationale, dissent, unresolved flags, and implementation references.
- Q4: fallback — session and peer favor labeled fresh-context fallback, then pause if no reviewer is available rather than silently proceed without review.

## Implementation handoffs
- Main session owns authoring the merged canonical source and consolidation, authorized by the original merge request and clarified answers. No implementation subagent has been launched; each future kickoff requires acceptance.
- Review/behavioral-test subagents are read-only checks, not implementation kickoffs.

## Implementation plan
- [x] Observe the old workflow in a fresh-context behavioral scenario before editing.
- [x] Rewrite coding-agents/source/grill-me.md with the settled workflow; consolidate grill-me-2.md.
- [x] Document canonical usage and the what/why in coding-agents/README.md, beyond this capture.
- [x] Forward-test with fresh-context agents: capped frontier/dependent question, independent peer inputs/options, partial answers and P acceptance, knowledge diffusion/Git recovery.
- [x] Run python3 -m unittest discover -s coding-agents -p test_build.py; rebuild through the canonical generator and verify single-skill rendering.
- [x] Review final diff, address defects, commit only task files on master; record outcome here.

## Session assessment before final design check
- Keep a single mode: skill source and remove the duplicate after consolidation.
- Author a concise self-contained workflow: setup/capture; dependency frontier; peer-generated options; session/peer synthesis; checkpoint each received answer message; scoped P proposals and accepted handoffs; verification and documentation diffusion.
- Record session options and recommendations before reading the peer response; keep this private assessment out of the peer brief.
- Preserve brainstorms by default. Commit captured decisions before any optional removal, and update relevant maintained docs within the implementation task.
- Do not infer merge/deploy authority from P acceptance; follow repo workflow and stopping point. Handoff can complete while unrelated branches remain open.

## Verification
- Existing-skill behavioral baseline (fresh-context subagent): with six independent ready questions and one dependent question, it asks all six, provides no durable capture, and defers even an agreed serializer task until whole-session confirmation. These are observed gaps against the requested merged behavior.
- External guidance: distinguish observations from interpretations; keep question context focused on why the decision matters. Source: https://www.gov.uk/service-manual/user-research/analyse-a-research-session and https://design-system.service.gov.uk/patterns/question-pages/.
- External divergence: GOV.UK's phase-based discovery discourages building during discovery. This user explicitly wants branch-level implementation offers; the relevant safeguard to decide is readiness of that branch, rather than importing a whole-project phase gate.
- Original inputs and full decision capture preserved by commit 3a4b289 before removing the duplicate source.
- Generator contract test: 1 test passed. Generator rebuilt 19 agents and 8 skills; only pre-existing commit-agent permission-translation warnings.
- Rendering checks: Claude, Codex, and Pi each contain the complete canonical grill-me body and name; no grill-me-2 source or generated artifact remains.
- Existing Claude and Codex skill symlinks already point to canonical generated directories, so the rebuild applies the new skill without an Ansible run touching unrelated settings.
- Lasting workflow mechanics and rationale diffused into coding-agents/README.md; detailed Q&A retained here.
- Forward round simulation passed: coherent 2-question round under the cap; blocked dependency omitted; neutral peer brief without session options; partial answers preserved; scope change forces re-peer; factual implementation finding prevents displaying stale options.
- Forward handoff simulation passed: checkpoint before P1 launch, P2 remains unaccepted; sequential mode blocks next display, explicit concurrent selection permits independent interviewing; fallback labeled; docs diffusion and Git protection precede pruning; unresolved delivery prevents blanket completion.
- Unique defect from forward handoff review: require user agreement to deferrals so an agent cannot manufacture closure. Fixed. Added verification: label unknown answering-model identity rather than guessing.
- Other review observations (reasonable preparation threshold, no default stopping point, broad disjoint-ownership concept) had no decision impact: these are deliberate context-dependent choices under applicable repository guidance. The existing prohibition on discarding uncommitted detail already covers minor pruning.
- Fresh-context final diff reviewer: no concrete defects found; coverage and README/source agreement inspected independently.
- Final cross-model diff reviewer: Claude Opus 5.5, supports. Complete JSON read. Added verification: peer-review uses fixed review-shaped JSON, so request Q-ID-labeled options/tradeoffs/recommendations within counterproposal and clarify missing assessments. Implemented; real 3-question call pending.
- Changed decision from cross-model diff review: shrink README to canonical pointer and rationale instead of duplicating the protocol. Removed redundant delegation/policy/revalidation wording from the source.
- Rejected false positive: asking for attempted falsifications is useful even though the tool schema requires that field; an empty field passes schema, and fresh-context fallback has no guaranteed schema. Keep the substantive request.
- No decision impact: retain short complete-response and review-impact rules so the peer gate is self-contained, including fallback behavior. These are critical to this workflow rather than generic process padding.
- Real 3-Q option-generation check: Claude Opus 5.5 returned clearly labeled Q1/Q2/Q3 sections with independently generated options, tradeoffs, and recommendations within counterproposal. Findings challenged dependencies and missing facts; attempted falsifications were substantive. Added verification confirms the mapping works without inventing peer views.
- Skill validator initially could not import yaml under default python3. Ran the same validator with the installed Ansible Python, which already provides PyYAML: Skill is valid. No dependency or host configuration changes made.
- Independent IC comparison found the missing investigation/planning/review depth: read-only subsystem/stack exploration, separate cited web research, outcome-versus-solution premise/diagnosis checks, concrete invariants/change budget, independent post-green review, CI followthrough, and architecture/reading-guide deliverables. These unique gaps are now addressed.
- Fresh-context reviewer re-read the updated source and README and found no remaining concrete defects, including against the new IC-depth requirement.
- IC-depth forward simulation exercised read-only call-path exploration, separate cited external research, premise/diagnosis challenge, manual freshness-contract decisions, concrete P plans, and a queue-semantics scope expansion requiring pause and user decision. This confirmed the desired depth is present.
- Unique defect: sequential finish-before-next-round could deadlock when implementation needs a reopened decision. Added an explicit exception for required blocker-resolution rounds, with affected agents paused and partial edits reported. Added verification: run/record diagnostic falsification observations and prohibit completion with failing required checks/blocking findings.
- No decision impact from other simulation observations: IC is a depth comparison, not a requirement to load its conflicting execution rules; repository-specific stopping points and specialized review criteria remain supplied by applicable guidance and task briefs.
- Targeted recheck confirmed the sequential blocker-resolution exception and pause/report mechanics resolve the simulated P1 queue-semantics deadlock.
- Final IC-depth cross-model diff review: Claude Opus 5.5 supports; complete JSON read. Unique defect: an unrestricted implementation-agent choice could invoke autonomous IC, duplicating gates and conflicting checkout/shipping rules. Fixed by scoped worker/stack implementers, with main session retaining peer/review/decision/delivery gates.
- Corrected stale capture wording about the initially untracked second source; its recovery commit is now explicit.
- Rejected false positive: unconditional P-task delegation is intentional here; user explicitly gives main session interviewing/architecture/orchestration and asks for subagent kickoffs. Do not introduce main-thread implementation exceptions or autonomous task expansion.
- No decision impact: keep concise peer-integrity and accepted-work authority instructions as critical self-contained gates. No further generic process additions from redundancy suggestions.
- Final fresh-context review found no defects in the ongoing-workstream distinction or earlier gates. Final behavior simulation confirmed that P1 completion does not close a workstream with pending investigations/blocked decisions, and P2 uses scoped implementers while main retains gates.
- Final generator test passed (1 test), rebuild succeeded, and the generated skill passed frontmatter validation. Existing permission-translation warnings are unrelated to this change. Task-scoped whitespace check passed.
- Complete current decisions and detailed Q&A retained here. Lasting workflow/interaction semantics live in coding-agents/source/grill-me.md; coding-agents/README.md explains the IC/grill-me distinction and points to the canonical protocol.
- Final delivery is a local master commit of the canonical source, duplicate deletion, README, and this capture. No PR/remote CI is in scope; local checks and workflow simulations are the validation evidence.

## Open flags
- None. All material workflow choices are settled.
