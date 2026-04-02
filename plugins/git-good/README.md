# git-good

Always-on safety guardrails for git operations in AI-assisted development.

## What it does

Provides ambient rules that prevent common LLM mistakes with git:

- **Fixup, not amend** - uses `git commit --fixup` so you can review changes before squashing
- **Surgical conflict resolution** - edits conflict markers instead of replacing whole files
- **Rebase safety protocol** - pre-flight checklist, per-commit validation, post-rebase verification
- **Conflict resolution maps** - plans resolutions before starting complex rebases
- **rerere cache management** - prevents poisoned caches from silently replaying bad resolutions
- **Destructive command safety** - never force-pushes, resets, or deletes without asking

## What it doesn't do

This skill has no style opinions. It does not impose:

- Branch naming conventions
- Commit message formats
- PR templates or workflows
- Merge vs rebase preferences

Instead, it checks the user's existing conventions and follows them.

## Prerequisites

The skill checks for and recommends:

- `merge.conflictstyle = diff3` (required for conflict resolution)
- `rerere.enabled = true` (recommended for rebase-heavy workflows)

## Installation

```
/plugin install MattKotsenas/agent-plugins:git-good
```
