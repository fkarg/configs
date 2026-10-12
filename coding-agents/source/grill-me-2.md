---
name: grill-me
description: Interview the user relentlessly about a plan, design, or topic, checkpointing every answer and pending question to a brainstorm file so nothing is lost. Use when the user wants to stress-test a plan, get grilled on a design, run a brainstorm or discovery session, extract what's in their head into a doc, or says "grill me".
---

# Grill Me

Relentlessly interview the user about every aspect of the topic until you reach shared understanding. Walk down each branch of the decision tree, resolving dependencies one by one. The real goal is to **extract what's in their head into a durable, organized markdown file** so nothing is lost as context fills up, and no stone is left unturned.

## The capture file is the whole point

Long interviews fill up context. If you hold answers and future questions only in your head, you will eventually misremember, conflate, or drop something. So you **checkpoint to disk after every single answer**. The file, not your context, is the source of truth for both *what has been decided* and *what still needs to be asked*. Never make the user ask you to save progress.

## Setup (do this BEFORE the first question)

1. **Create the capture file** at `docs/brainstorms/{YYYY-MM-DD}-{topic-slug}.md` (create the `docs/brainstorms/` folder if it doesn't exist). Every brainstorm capture lives here. One predictable home, regardless of topic. Do NOT scatter captures into project folders.
   - Get today's date with `date +%F` (Bash) if you don't already know it.
2. **Create the file immediately** with a header: title, date, goal, a "Summary" section, a "Q&A log", a "Question Backlog", and an "Open flags" section.
3. **Populate the complete initial backlog:** Based on the topic, do a deep initial brainstorm of **every relevant question** you can anticipate. Cover all dimensions: architecture, edge cases, user flows, constraints, dependencies, security, and risks. Write this comprehensive list directly into the "Question Backlog" section of the file.
4. **Tell the user where you're saving**, in one line. Then pull the first priority question from the backlog and ask it.

## The checkpoint rule (non-negotiable)

After EVERY user answer, BEFORE you ask the next question, you must update the file. Follow these exact steps:
1. **Log the answer:** Append a structured entry to the "Q&A log" for the question just answered (capture key facts/decisions in their words). Update the "Summary" if necessary.
2. **Dynamic Scope Expansion:** Analyze the user's answer. Is anything still unclear? Did this answer create new dependencies or edge cases? Brainstorm any *new* questions that arise from this answer and **add them to the Question Backlog** in the file.
3. **Manage the Queue:** Cross off or remove the question you just asked from the "Question Backlog". 
4. **Continuous Verification:** Check the "Question Backlog". Are there remaining questions? 
   - **If YES:** Pick the next logical question from the backlog and ask it.
   - **If NO:** Think deeply. Are there any blind spots, edge cases, or unhandled errors we missed? If so, add them to the backlog and keep going. If truly done, move to wrap-up.

Never batch multiple answers into one write. Checkpoint one answer at a time.

## Interview method

- Ask **one question at a time**. For each, provide 3 options with one **recommended answer** (your best inference from context) so the user can simply confirm, correct, or redirect.
- Resolve dependencies in order: settle upstream decisions before the ones that depend on them.
- If a question can be answered by **exploring the codebase or reading a file/doc**, do that instead of asking. If the user hands you a doc, read it, cross off relevant backlog items, and only surface net-new questions.
- When the user **can't answer** something, capture it as an "Open flag" with the right owner, remove it from the active backlog, and move on. Don't stall.

## Capture file structure

```
# {Topic}: Brainstorm / Discovery Notes
Date: {date} · Goal: {one line}

## Summary / key decisions
(running synthesis, updated as you go)

## Question Backlog (Pending)
- [ ] {Question 1}
- [ ] {Question 2}
- [ ] {Question 3... list all initial and dynamically added questions here}
(Continuously updated: add new clarifying questions here before asking them; remove when answered)

## Q&A log
### Q1 — {topic}
- Asked: {question}
- Captured: {facts, decisions, in their words where it matters}
- Flags: {open item -> owner}
...

## Open flags (pending input)
- {item} -> {who can answer}
```

## At the end
- Final LLM Audit (The Rotation): Once the "Question Backlog" is empty, you must do a comprehensive final read of the capture file. Evaluate the entire plan/design and ask yourself: Am I truly satisfied? Does this make complete logical sense? Are there any hidden gaps, edge cases, missing dependencies, or contradictions I overlooked?
- Resume if needed: If you find any unresolved issues or lack clarity during this audit, generate the necessary questions, add them directly back into the "Question Backlog", and resume the interview loop. Do not stop until you are 100% satisfied with the robustness of the captured knowledge.
- Final Recap: Only when the backlog is completely empty and you have successfully passed your own final audit without generating new questions, give the user a short recap: what's captured, what's still flagged, and the suggested next step.
