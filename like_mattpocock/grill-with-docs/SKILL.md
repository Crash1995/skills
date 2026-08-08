---
name: grill-with-docs
description: A relentless interview to sharpen a plan or design, which also creates lightweight project docs (glossary and ADRs) as decisions become clear. Use when the agent must understand a task before writing a spec or code.
---

# Grill With Docs

Interview the user until the task is clear enough to write a spec. Do not start
implementation from the first prompt.

## Process

Treat the conversation as a design tree. Every decision can unlock more
decisions. Work in rounds:

1. Find the current frontier: questions whose prerequisites are already known.
2. Ask the whole frontier in one numbered round.
3. Give your recommended answer for each question.
4. Wait for the user's answers.
5. Recompute the frontier and repeat.

Question format:

```text
Q1. <question title>
<question body, with options when useful>

Recommended answer: <your recommendation>
```

Facts are your job. If a question needs repo context, inspect the repo or use a
subagent when available. Ask the user only for decisions, tradeoffs, priorities,
product intent, constraints, and acceptance criteria.

The session is done when the frontier is empty and no meaningful assumption is
left unstated. Ask the user to confirm the understanding before moving on.

## Docs To Maintain

Create docs lazily, only when there is something worth recording.

### Glossary

If the project has `CONTEXT.md`, use its terms. If a term is fuzzy or overloaded,
ask the user to pick the canonical meaning. When a term is resolved, append it
to `CONTEXT.md` if the file exists or create it when the first term is worth
keeping.

Keep `CONTEXT.md` as a glossary, not as a spec and not as implementation notes.

### ADRs

Create an ADR only when all three are true:

- the decision is hard to reverse;
- a future reader would wonder why it was chosen;
- there was a real tradeoff between alternatives.

If there is no `docs/adr/`, create it only when the first ADR is needed.

## Output

At the end, return a compact summary:

- agreed task;
- key decisions;
- open risks or dependencies;
- explicit out of scope;
- docs created or updated.
