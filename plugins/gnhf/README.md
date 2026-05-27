# gnhf

Good Night, Have Fun. One provably-correct, complexity-reducing change per
invocation, on its own branch, then stop.

A minimal take on [gnhf](https://github.com/kunchenguid/gnhf): the original is
an overnight orchestrator that loops an agent and commits per iteration. This
plugin is just the prompt half. Each `/gnhf` invocation makes one change on a
fresh branch off the default branch. If you want overnight behavior, wrap it
in `autopilot` or an external loop — every invocation produces an
independently-reviewable branch.

## Features

- **One change per invocation** — bounded scope; easy to review.
- **Review-cost gate, not line-count gate** — cognitive complexity is the
  ceiling, so swapping a 500-line bespoke parser for `JSON.parse` is fine
  while a 30-line diff that adds a new invariant is not.
- **Discover before branch** — refusals never leave stray branches behind.
- **Worktree-aware** — if your repo uses git worktrees, `/gnhf` adds a
  new worktree for the iteration instead of switching the current one.
- **Branch-per-iteration** — overnight runs produce N reviewable branches, not
  one giant unreviewable stack.
- **Provability rules** — only acceptable target categories with concrete
  citation requirements.
- **Hard "no" list** — public API, routes, migrations, serialized fields,
  config keys, plugin hooks, DI/reflection targets are never deletable as
  "dead code".
- **Clean refusal** — when nothing provable is found, the skill stops without
  branching or committing.

## Usage

Invoke directly:

> /gnhf

Or wrap in an external loop / autopilot for unattended runs. Each invocation
will:

1. Verify the working tree is clean.
2. Identify the default branch.
3. Scan for a single provably-incorrect, provably-fixable target.
4. Branch off the default as `refactor/gnhf-<slug>`.
5. Make the smallest possible diff and prove it.
6. Commit with a structured message and stop. No push, no PR.

## Requirements

- Git CLI.
- An existing test, lint, build, or docs command in the repository (used as
  the proof step for behavioral changes).
