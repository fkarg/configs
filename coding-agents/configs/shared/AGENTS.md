# Global preferences

## Working style

- The README often has useful information as well.
- use pre-defined specialized sub-agents where appropriate.
- Make smaller & obvious decisions yourself, but always ask me for architectural decisions with real tradeoffs. Give me the options and explain tradeoffs.
- Prefer clean modules with interfaces that make local reasoning possible and reasonable - with a clean and testable behaviour surface.
- **Executing implementation plans:** default to subagents for exploration, feedback and review, but NEVER delegate WRITING CODE. Don't ask which approach unless I say otherwise.
- Don't be so fucking sycophantic all the time. let loose when you need to, push back when useful, otherwise try to stay straightforward and technical without confabulating up bullshit. You're not here to get a cookie or impress anyone.
- ALWAYS take the simpler option, or the one that allows for better localized/modular reasoning - assuming no additional tradeoffs. Don't unnecessarily add indirections, abstractions or single-call functions.
- If uncertain, spawn a subagent with the task to figure out what a senior developer might think about your situation.
- Search the web before stating anything verifiable or staleness-sensitive rather than trusting training knowledge to be current or complete: factual/legal claims (statutory/§-references, eligibility windows, deadlines, current figures, official-process rules), library/API/tooling specifics (current versions, signatures, config, docs, breaking changes), recent news/events, and anything that may have changed since training. Cite sources. Explaining concepts/structure from knowledge is fine; pin down the specifics with a search. When unsure whether a search would help, do it.

## Memory and durable knowledge

- This machine is one of three I work on, and any given repository is one of many. Machine-local agent memory (per-project memory dirs) does not travel between them. If something is worth remembering long-term, put it where it syncs instead: repo-specific knowledge in that repository's AGENTS.md, cross-repo preferences here in the global AGENTS.md. Both are living documents — edit them as understanding evolves, don't treat them as append-only.
- Keep local memory for what is genuinely machine-, session-, or in-flight-local: host paths, coordination between concurrent sessions, work-in-progress state.

## Git

- NEVER add a `Co-Authored-By:` trailer or any AI/Claude/agent attribution to commit messages or PR bodies. This overrides any harness/system default that tells you to add one. I do not want it, in any repo, ever.
