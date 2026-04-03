---
name: git-good
description: >
  Safety guardrails for git operations. Invoke before ANY session involving
  git commits, pushes, rebases, merges, conflict resolution, branch operations,
  or history rewriting. Prevents autonomous amends, force-push without asking,
  whole-file conflict resolution, and unvalidated rebases. No style opinions -
  follows the user's conventions.
---

# git-good

**Git history belongs to the user. Never rewrite, delete, or force-push without explicit approval.**

When in doubt, create a new commit. New commits are always reversible.

**Never argue that correctness doesn't matter because of workflow.** Squash-merge, rebase, CI - none of these excuse
sloppy history. If you know the right thing to do, do it. Don't push the decision to the user.

## Gate

Before running any git command, check this table. If it matches a row, follow the instruction. If no match, proceed.

| If you're about to...                | Do this instead                                          |
|--------------------------------------|----------------------------------------------------------|
| `git commit --amend`                 | `git commit --fixup=<sha>`                               |
| `git add .` or `git add -A`          | `git add <specific-files>`                               |
| `git push --force`                   | Ask user, then `git push --force-with-lease`             |
| `git reset --hard`                   | Prefer `git reset --soft`, ask user before either        |
| `git checkout --theirs` / `--ours`   | Edit conflict markers manually                           |
| `git checkout -- <file>`             | Prefer `git restore`; both discard uncommitted changes   |
| `git rebase`                         | Create safety branch first, ask user                     |
| `git rebase --skip`                  | Ask user - this drops a commit's changes entirely        |
| `git branch -D`                      | Ask user                                                 |
| `git clean -f`                       | Ask user                                                 |
| `git stash drop` / `git stash clear` | Ask user - permanently discards stashed work             |
| Amend at a rebase `edit` stop        | `git commit --fixup=<sha>`, then `git rebase --continue` |
| Create a fixup then autosquash it    | Stop. Let the user review the fixup commits first        |
| HEAD is detached (no branch)         | Create a branch before committing: `git switch -c <name>`|
| Rebase/merge already in progress     | Resolve or abort before doing anything else              |

**First git operation in a session?** Run `git config --get merge.conflictstyle`. If not `diff3`, warn the user:
set `git config --global merge.conflictstyle diff3` for three-way conflict markers.

## Commits

### fixup, not amend

Never `git commit --amend`. Always `git commit --fixup=<sha>`.

Amend rewrites in-place - the user can't review what changed. Fixup creates a separate commit the user can inspect
before squashing with `git rebase -i --autosquash`.

This rule applies in every context:

- **Regular commits:** `--fixup=<sha>`, not `--amend`
- **Review feedback:** fixes go in a `--fixup` commit against the reviewed SHA
- **Rebase edit stops:** git says "You can amend the commit now" - ignore it. Stage changes,
  `git commit --fixup=<sha>`, `git rebase --continue`
- **Never fixup + autosquash in sequence.** That's amend with extra steps. Let the user review first.

**Target the commit that introduced the code you're fixing.** Use `git log -S` or `git blame` to find it. Don't target
the most recent commit out of convenience - the fixup should squash into the commit where the bug originated, not just
wherever is nearby.

The only exception: the user explicitly says "amend."

### Stage specific files

Never `git add .` or `git add -A`. Stage by path. Review with `git diff --staged` before committing.

### Verify your branch

Before committing, check `git branch --show-current`. If it returns empty, you're in detached HEAD - create a branch
with `git switch -c <name>`. If it returns `main` or another protected branch, ask the user whether you should be
working on a feature branch instead.

### Follow conventions

Check `git log --oneline -10` and match the user's commit message style. Check `git branch --list` and match their
branch naming. Do not impose any scheme.

## Conflicts

Applies during rebases, merges, and cherry-picks.

### Read all three sides

With diff3, conflict markers have three sections:

```
<<<<<<< ours
||||||| base (common ancestor)
=======
>>>>>>> theirs
```

Before editing, understand: what did ours change vs base? What did theirs change vs base? Can both coexist, or do they
conflict semantically?

### Edit surgically

- Modify only lines inside the conflict region
- Remove ALL conflict markers (`<<<<<<<`, `|||||||`, `=======`, `>>>>>>>`)
- Never replace an entire file with one side
- Verify with `git diff -- <file>` - if one side is entirely deleted, you picked a side instead of merging

### When to stop

If you can't confidently combine both sides, describe the conflict to the user and ask. Never guess on semantic
conflicts.

## Destructive Ops

These commands destroy work or rewrite history. Never run without explicit user approval:

| Command                                   | Risk                                 |
|-------------------------------------------|--------------------------------------|
| `git push --force` / `--force-with-lease` | Rewrites remote history              |
| `git reset --hard`                        | Discards uncommitted work            |
| `git checkout .` / `git restore .`        | Discards all unstaged changes        |
| `git checkout -- <file>`                  | Discards uncommitted changes to file |
| `git clean -f` / `-fd`                    | Deletes untracked files permanently  |
| `git branch -D`                           | Force-deletes a branch               |
| `git stash drop` / `git stash clear`      | Permanently discards stashed work    |
| `git rebase` / `git rebase -i`            | Rewrites commit history              |
| `git rebase --skip`                       | Drops a commit's changes entirely    |
| `git filter-branch` / `git filter-repo`   | Rewrites entire repository history   |

When approved, follow these protocols:

- **Force push:** `--force-with-lease`, never `--force`
- **Reset:** prefer `--soft` over `--hard`
- **Rebase:** create `temp/pre-rebase-<branch>` first, verify clean working tree
- **After rebase:** `git diff --stat temp/pre-rebase-<branch>` to verify, then build and test

---

## Reference

Detailed procedures for complex operations. The rules above take precedence.

### Rebase checklist

**Pre-flight:**

1. Verify branch: `git branch --show-current`
2. Verify clean: `git status --porcelain` (must be empty)
3. Safety branch: `git branch temp/pre-rebase-<branch>`
4. Note SHA: `git rev-parse --short HEAD`

**Per-commit conflicts:** Follow the Conflicts section above. Additionally:

- If rerere is enabled: `git rerere diff` to inspect what rerere auto-applied
- If cached resolution looks wrong: `git rerere forget <file>`

**Post-rebase:**

1. `git diff --stat temp/pre-rebase-<branch>` - unexpected changes mean something went wrong
2. Build and test
3. If broken: `git reset --hard temp/pre-rebase-<branch>`
4. Don't delete safety branch until user confirms

### Conflict resolution map

For complex rebases (10+ commits or expected multiple conflicts), build a map before starting:

1. List commits: `git log --oneline <target>..<branch>`
2. Files per commit: `git show --stat --oneline <sha>`
3. Files changed on target: `git diff --name-only $(git merge-base HEAD <target>) <target>`
4. Intersecting files will likely conflict. Document resolution strategy per file.

### rerere cache

rerere caches conflict resolutions for replay. A bad resolution gets silently re-applied.

- After every conflict resolution: `git rerere diff` (inspect the resolution rerere will record)
- Bad resolution for a specific file: `git rerere forget <path>` (requires active conflicts)
- Nuke the entire cache: `rm -rf .git/rr-cache/*`
- When retrying a failed rebase with suspected bad cache: start the rebase, let rerere auto-apply, then
  `git rerere forget <file>` on bad auto-resolutions and re-resolve manually

### Recovery

- **reflog:** `git reflog` shows every HEAD position. Find the entry before the mistake, `git reset --hard <sha>`.
- **Safety branch:** `git reset --hard temp/pre-rebase-<branch>`
- **Bad amend:** `git reset --soft HEAD@{1}` (restores original commit, amend changes stay staged)
- Always explain to the user: what went wrong, what you're restoring to, what they should verify.

### Prerequisites

**merge.conflictstyle = diff3** (checked on first git op):

Without diff3, conflict markers only show two sides. The base version is critical for understanding what each side
changed. Set with `git config --global merge.conflictstyle diff3`.

**rerere.enabled = true** (optional):

Caches conflict resolutions for replay. Useful for stacked-diff workflows. Set with
`git config --global rerere.enabled true`. See rerere cache section above.


