---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
---

Implement the work described by the user in the spec or tickets.

Before editing, capture the current `HEAD` with `git rev-parse HEAD`. This is
the fixed point for review unless the user or caller already supplied one.

Use test-driven development where possible, at pre-agreed seams. Tests should
verify behavior through public interfaces, not implementation details. Write a
failing test first when the seam is clear, implement the smallest change that
passes, then refactor only when the behavior is green.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use /code-review to review the work. Pass the fixed point, spec path,
and current ticket path/number when you have them.

Commit your work to the current branch when the repo policy allows commits. If
commits are not allowed, leave the working tree uncommitted and still run
`code-review` against the captured fixed point in WIP mode.
