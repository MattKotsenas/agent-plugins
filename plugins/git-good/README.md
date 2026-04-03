# git-good

Safety guardrails for git operations in AI-assisted development.

## What it does

One rule: **git history belongs to the user.** The skill enforces this through:

- **A decision gate** checked before every git command - a table mapping dangerous commands to safe alternatives
- **Commits:** fixup-not-amend, specific file staging, convention matching
- **Conflicts:** three-way reads, surgical edits, no whole-file replacement
- **Destructive ops:** never force-push, reset, rebase, or delete without asking

Reference sections cover rebase checklists, conflict resolution maps, rerere cache management, and recovery procedures.

## What it doesn't do

No style opinions. No branch naming, commit message formats, PR templates, or merge-vs-rebase preferences. It checks
the user's existing conventions and follows them.

## Prerequisites

The skill checks for `merge.conflictstyle = diff3` on the first git operation (required for three-way conflict markers).

## Installation

```
/plugin install MattKotsenas/agent-plugins:git-good
```
