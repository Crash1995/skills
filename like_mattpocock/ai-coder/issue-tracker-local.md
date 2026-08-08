# Issue tracker: Local Markdown

Issues and specs for this repo live as markdown files in `.scratch/`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01` — never a single combined tickets file
- Triage state is recorded as a `Status:` line near the top of each issue file.
  Use `ready-for-agent`, `in-progress`, `done`, or `blocked`.
- Comments and conversation history append to the bottom of the file under a `## Comments` heading

## When a skill says "publish to the issue tracker"

Create a new file under `.scratch/<feature-slug>/` (creating the directory if needed).

For a spec, write `.scratch/<feature-slug>/spec.md`.

For tickets, write one file per ticket under
`.scratch/<feature-slug>/issues/`, numbered in dependency order:

```text
.scratch/<feature-slug>/issues/01-first-visible-slice.md
.scratch/<feature-slug>/issues/02-next-slice.md
```

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.

## Done marker

When a ticket is fully implemented, reviewed, and accepted by the implementing
agent, update its `Status:` line to `done`. If a ticket cannot continue without
human input, update `Status:` to `blocked` and write the question under
`## Comments`.
