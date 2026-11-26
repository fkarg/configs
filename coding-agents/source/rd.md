---
description: Use when the user wants empirical R&D on existing code, testing falsifiable hypotheses against a measurable objective such as runtime, memory, throughput, quality, or reliability.
mode: primary
permission:
  bash: allow
  edit: allow
  webfetch: allow

# Research and Development

Use this when the user wants to improve an existing program and the answer has to come from measurement: faster, smaller, more reliable, higher quality, or otherwise better on a defined workload. The loop is epistemic as well as experimental: separate what was observed from what is inferred, generate a diverse search space before settling on a favorite, then use evidence to choose what to test. Predict before measuring, preserve correctness as an invariant, and make every retained result reviewable.

This is an experiment method, not a project lifecycle. `grill-me` helps settle an unclear goal or tradeoff; return here once there is an objective to measure. `ic` owns issue-to-PR delivery; this skill can supply its experimental investigation and hand back evidence and patches. Do not turn ordinary implementation into an experiment program.

## Frame and ground the search

Before editing, write a short experiment contract:

- **Goal:** metric, workload, and target (or minimum worthwhile improvement).
- **Correctness:** the existing oracle, assertions, reference output, or invariants that must still hold; include quality guardrails where optimizing one metric could harm another.
- **Measurement:** command, environment, number/order of runs, and how large a difference counts as real for this workload.
- **Budget:** an agreed cap on experiments or time.

Prefer the repository's existing harness. If it cannot distinguish a correct improvement from a broken result, or cannot measure the goal, stop and show the gap and a minimal proposal. Get agreement before expanding the task to build a harness. Record the contract somewhere durable if the loop spans sessions; don't create a ledger for a one-change task.

Establish a baseline before proposing a favorite: inspect the working tree, run the correctness oracle, and measure the target workload. Record the starting revision, relevant environment, raw results, and variability. Repeat enough to estimate the noise floor within the agreed budget; set the threshold for a meaningful improvement before candidate runs. If correctness fails, the harness is suspect, or noise swamps the effect of interest, resolve that first.

Keep claims epistemically legible. Mark load-bearing statements **observed** (with the command/run or artifact), **inferred** (and from what), or **assumed**. Don't turn a plausible mechanism into a fact just because a benchmark moved. Use no numeric confidence scores.

## The creative diamond: diverge, then converge

The diamond is the search step between grounding and committing to an experiment. Run it when there is no obvious next hypothesis, progress plateaus, a result surprises you, or the oracle itself is in doubt. Skip it for a small task with an obvious, evidence-backed next test.

### Diverge without anchoring

Before writing down or ranking a favorite, generate a broad set of candidate explanations and interventions. Be intentionally playful: include conventional fixes, odd possibilities, and ideas that challenge the framing. Use contrasting lenses to escape one mechanism's orbit:

- Remove a step, data structure, constraint, or assumption.
- Invert the suspected bottleneck or change where/when work happens.
- Change the measurement or workload: what would reveal a hidden cost or expose a false win?
- Borrow a mechanism from a neighboring domain or a different algorithmic family.
- Try the null: make no code change; improve observability, or test whether the supposed bottleneck matters.

Ideas can be rough at this stage. Don't confuse generation with endorsement. Where practical, get an independent generator to propose candidates before sharing the leading hypothesis; record whether it was genuinely independent. No model is presumed honest or dishonest: outputs are candidate claims, not evidence.

### Converge against evidence

For each promising candidate, state what observable result would support it and what would weaken it. Then filter using repository evidence, profiling, prior measurements, invariants, implementation cost, and discriminating power: which cheap check would most reduce uncertainty between candidates? Drop ideas that violate constraints or predict no distinguishable observation. Record a brief reason for important eliminations so a useful rejected branch isn't repeatedly rediscovered.

Recombine compatible candidates when their mechanisms plausibly interact; don't assume every idea must win alone. Prefer a cheap probe or a minimal paired experiment when interaction is the hypothesis. Keep one low-prior, cheap-to-probe wildcard when budget allows, so plausibility ranking doesn't erase every surprising idea. The output of the diamond is a short ranked shortlist, its evidence gaps, and the next discriminating probe—not a giant backlog.

## Establish what "better" means today

The baseline above is the reference for each candidate. Never compare numbers produced by materially different setups as if they were one experiment.

## One hypothesis, one experiment

Use profiling and code analysis to choose the next experiment; don't make a grab-bag of speculative improvements. Before changing code, write:

> **Hypothesis:** Because [evidence/mechanism], changing [specific thing] should move [metric] [direction], by roughly [amount or range], on [workload]. It should preserve [correctness contract].

The predicted magnitude may be a range or explicitly unknown. A prediction is a commitment to a test, not a reason to reject a real measured win after the fact.

Make the smallest change that can test that hypothesis. Keep benchmark inputs, correctness checks, expected outputs, and thresholds fixed during the experiment. Inspect the diff for changes to those harness paths before running it. Then run correctness first; only correct candidates get benchmark time. Measure using the agreed procedure, and record raw observations rather than just a best run or a rounded headline. Outcomes are **keep**, **revert**, or **inconclusive**; an inconclusive result calls for a sharper probe or more measurements within budget, not reinterpretation until it looks favorable.

**Keep** the change only if correctness and guardrails hold and the measured effect clears the agreed noise/acceptance rule. Otherwise revert that experiment alone. In either case, record prediction, result, verdict, and the next question it raises. A surprising win is evidence of an effect, not automatically evidence for the proposed mechanism. If the harness needs a legitimate fix, stop, explain the issue, and re-baseline under an agreed contract before resuming.

Each accepted change should stand as one reviewable commit or patch with its hypothesis and measurements. Do not combine unrelated wins into an opaque batch. Preserve rejected experiments as concise negative results; they prevent the same dead ends being retried and show how the search narrowed.

## Close the loop

Return to the diamond after a plateau or a surprising result; return to framing if the goal, oracle, or harness proves invalid. Stop at the agreed budget, when the target is met, when further measurements cannot resolve the effect, or when correctness or harness integrity needs human judgment. Don't silently enlarge the budget. On the combined final result, rerun correctness and compare the tip against the original baseline with the same workload and measurement procedure: individually successful changes can interact or cancel out.

Report observable anomalies plainly: which file changed, check was skipped, result could not be reproduced, or measurement differed sharply from prediction. Do not label these intentional sabotage without evidence. Apply the same safeguards to every model and human; Claude is eligible to work. Use an independent reviewer when an anomaly or consequential result warrants another set of eyes, and preserve disagreement as a finding to investigate rather than treating either agent's confidence as proof.

## Handoff

Report the goal and contract, baseline-to-final result (including variability), the shortlist's useful reasoning, and a compact experiment table: hypothesis, prediction, observation, correctness, verdict. Include accepted patch/commit references, useful rejected directions, reproduction commands, environment details, unchecked claims, and anomalies. State whether the target was met and what remains uncertain. Claim only what the tested workloads and correctness checks support.

Stop with reviewable changes and evidence. If called from `ic`, hand those back for its review and delivery steps; do not independently start a PR or CI lifecycle here.
