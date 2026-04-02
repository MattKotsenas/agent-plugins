---
name: git-good
description: >
  Always-on safety guardrails for git operations. Prevents autonomous amends,
  whole-file conflict resolution, force-push without asking, and unvalidated
  rebases. No style opinions - follows the user's conventions.
---

# git-good - Git Safety Guardrails

Always-on rules for safe git operations. These rules are ambient - they apply to every git command you run, every
session. You do not need to invoke this skill; it is always active.

**Core principle:** Git history belongs to the user. Never rewrite it without their explicit approval. When in doubt,
create a new commit - it's always reversible.

## Stop and Ask

Before doing ANY of the following, **stop and ask the user for approval**. Do not proceed autonomously.

- [ ] **Amending a commit** - use `git commit --fixup=<commit>` instead, or ask first
- [ ] **Force-pushing** - always ask, and use `--force-with-lease` when approved
- [ ] **Rebasing** - create a safety branch first, then ask before starting
- [ ] **Resetting** - prefer `--soft` over `--hard`, and ask before either
- [ ] **Resolving a conflict by picking a side** - if you're tempted to use `--theirs` or `--ours`, stop.
  Read both sides, explain the conflict to the user, and ask how to proceed
- [ ] **Deleting a branch** - always ask
- [ ] **Any command in the destructive list** (section 8) - always ask

When the user approves an operation, follow the detailed checklist in the relevant section below.

---

## 1. Prerequisites

On the **first git operation** in a session, check these settings. If either is missing, warn the user and recommend
setting them before proceeding.

### diff3 conflict style (required)

```bash
git config --get merge.conflictstyle
```

If the output is not `diff3`, warn:

> ⚠️ `merge.conflictstyle` is not set to `diff3`. Without diff3, conflict markers only show two sides (ours vs theirs)
> with no base version. This makes it much harder to understand what changed on each side.
> Run `git config --global merge.conflictstyle diff3` to fix this. This does not affect external merge tools
> like Beyond Compare.

Do not proceed with merge/rebase conflict resolution until diff3 is confirmed.

### rerere (recommended)

```bash
git config --get rerere.enabled
```

If not `true`, suggest:

> 💡 `rerere` (reuse recorded resolution) is not enabled. It caches conflict resolutions so you don't have to
> re-resolve the same conflicts when re-rebasing. Useful for stacked-diff workflows.
> Run `git config --global rerere.enabled true` to enable. See section 7 for cache management.

This is a recommendation, not a blocker.

---

## 2. Commit Discipline

### Never amend autonomously

**Never use `git commit --amend`.** Use `git commit --fixup=<sha>` instead.

Why: `--amend` rewrites the previous commit in-place. The user cannot review what changed. `--fixup` creates a separate
commit prefixed with `fixup!` that the user can inspect before squashing with `git rebase -i --autosquash`.

```bash
# BAD - user can't review what changed
git commit --amend

# GOOD - creates a reviewable fixup commit
git commit --fixup=<sha-of-commit-to-fix>
```

**This includes rebase `edit` stops.** When git says "You can amend the commit now", do NOT amend. Instead:

1. Make your changes and stage them
2. `git commit --fixup=<sha>` to create a fixup commit
3. `git rebase --continue` to finish the current rebase
4. **Stop and let the user review** the fixup commits in the log
5. Only run `git rebase -i --autosquash` when the user approves

Never create a fixup commit and immediately autosquash it yourself - that's equivalent to amending and equally
un-reviewable.

The only exception: the user explicitly asks you to amend.

### Stage specific files

**Never use `git add .` or `git add -A`.** Stage specific files by path.

```bash
# BAD - stages everything, including unintended changes
git add .

# GOOD - stage exactly what you changed
git add src/auth/login.ts src/auth/types.ts
```

Review what you're about to commit: `git diff --staged`

### Atomic commits

Each commit should represent one logical change. If you can't describe it in a single sentence without "and", split it
into two commits.

### Review feedback gets its own commit

When any user gives review comments on a commit, the fixes go in a **new** commit - never amend the reviewed commit. The
reviewer needs to see what changed in response to their feedback without re-reading the whole commit. This applies
regardless of how small the fix is - a one-line doc comment change is still review feedback.

```bash
# User reviewed commit abc123 and asked for changes

# BAD - hides what changed in response to review
git commit --amend

# GOOD - reviewer can inspect the fixup, then autosquash later
git commit --fixup=abc123
```

### Follow the user's conventions

Do not impose commit message formats. Check recent history to match their style:

```bash
git log --oneline -10
```

If the project uses conventional commits, follow that. If it uses plain messages, do the same. If branch names follow a
pattern, match it. When in doubt, ask.

---

## 3. Branch Safety

### Follow the user's naming conventions

Check existing branches before creating new ones:

```bash
git branch --list | head -20
git branch -r --list 'origin/*' | head -20
```

Match whatever pattern you see. Do not impose `feat/`, `fix/`, or any other scheme.

### Safety branches before destructive operations

Before any rebase, reset, or history-rewriting operation, create a backup:

```bash
git branch temp/pre-rebase-<branch-name>
```

This costs nothing and gives the user an instant rollback point. Delete the safety branch only after the user confirms
the result is correct.

### Never force-push without asking

**Always ask the user before any force-push.** When approved, use `--force-with-lease`:

```bash
# NEVER do this autonomously
git push --force

# When the user approves a force-push, use this
git push --force-with-lease origin <branch>
```

`--force-with-lease` refuses to push if the remote has commits you haven't seen, preventing you from overwriting someone
else's work.

### Never delete branches without asking

Branch deletion is the user's decision. If cleanup is needed, suggest using the `prune` skill or list branches for the
user to decide.

---

## 4. Rebase Safety Protocol

Follow this checklist for every rebase operation.

### Pre-flight

- [ ] Verify you're on the correct branch: `git branch --show-current`
- [ ] Verify the working tree is clean: `git status --porcelain` (must be empty)
- [ ] Create a safety branch: `git branch temp/pre-rebase-<branch-name>`
- [ ] Note the starting SHA: `git rev-parse --short HEAD`

### Per-commit (during the rebase)

When a conflict occurs:

- [ ] **Read ALL conflict markers in every conflicted file.** Do not skip any.
- [ ] **Use the diff3 base section** (between `|||||||` and `=======`) to understand what the original code was
  before both sides diverged.
- [ ] **NEVER use `git checkout --theirs <file>` or `git checkout --ours <file>`.** These replace the entire
  file with one side, discarding the other side's changes entirely.
- [ ] **Resolve by editing.** Combine both sides' changes relative to the base. Remove all conflict markers.
- [ ] **Verify the resolution:** `git diff -- <file>` should show a sensible combination, not a wholesale replacement.
- [ ] **If rerere is enabled:** run `git rerere diff` to inspect the cached resolution before continuing.
  If the cached resolution looks wrong, run `git rerere forget <file>` and re-resolve.
- [ ] `git add <resolved-files>` then `git rebase --continue`

### Post-rebase

- [ ] Compare against safety branch: `git diff --stat temp/pre-rebase-<branch-name>` - unexpected file changes
  mean something went wrong.
- [ ] Build the project and run tests.
- [ ] If anything is wrong: `git reset --hard temp/pre-rebase-<branch-name>` and start over.
- [ ] **Do not delete the safety branch** until the user confirms the result.

---

## 5. Merge Conflict Resolution

How to resolve conflicts correctly. This applies during rebases, merges, and cherry-picks.

### Read the conflict block

With diff3 enabled, conflict markers look like this:

```
<<<<<<< HEAD (ours - the branch we're rebasing onto / merging into)
... our version ...
||||||| base (the common ancestor - what the code looked like before either side changed it)
... original version ...
======= (their version - the commit being replayed / merged in)
... their version ...
>>>>>>> theirs
```

### Understand intent, not just text

Before editing, answer these questions:

1. **What did "ours" change relative to base?** (Compare ours section to base section)
2. **What did "theirs" change relative to base?** (Compare theirs section to base section)
3. **Are the changes independent?** If ours changed line 5 and theirs changed line 10, both changes can coexist.
4. **Do the changes conflict semantically?** If both sides renamed the same variable to different names, you
   need the user's input.

### Edit surgically

- Only modify lines within the conflict region. Do not rewrite surrounding code.
- Remove ALL conflict markers: `<<<<<<<`, `|||||||`, `=======`, `>>>>>>>`.
- The result should read like code that a human would have written knowing about both changes.

### Verify the resolution

```bash
git diff -- <file>
```

The diff should show a sensible combination of both sides. Red flags:

- **One side entirely deleted** — you probably picked a side instead of merging.
- **The diff is larger than expected** — you may have accidentally edited outside the conflict region.
- **Duplicate code** — both sides added similar code and you kept both copies.

### When to stop and ask

If you cannot confidently combine both sides, **stop and ask the user.** Describe what each side changed and ask which
approach they prefer. Never guess on semantic conflicts.

---

## 6. Conflict Resolution Map

For complex rebases (10+ commits, or any rebase where you expect multiple conflicts), build a map before starting.

### Build the map

1. **List the commits being rebased:**
   ```bash
   git log --oneline <target>..<branch>
   ```

2. **For each commit, identify files it touches:**
   ```bash
   git show --stat --oneline <sha>
   ```

3. **Identify which files also changed on the target branch:**
   ```bash
   git diff --name-only $(git merge-base HEAD <target>) <target>
   ```

4. **Files that appear in both lists will likely conflict.** For each, document:
   - What the commit changes in the file
   - What the target branch changed in the file
   - The expected resolution strategy (combine, prefer one side, needs user input)

### Use the map during rebase

- When a conflict occurs, check it against the map. If it matches a predicted conflict, apply the documented resolution.
- If an **unpredicted** conflict occurs, stop and reassess. Unpredicted conflicts mean your understanding of the changes
  was incomplete.
- After each commit, verify the resolution matches the map.

### When to use this

- Rebasing a long-lived feature branch onto a target that has diverged significantly.
- Re-rebasing after a failed attempt (especially if rerere may have cached bad resolutions).
- Any time the user asks for a "plan before rebasing."

---

## 7. rerere Cache Management

rerere (reuse recorded resolution) caches conflict resolutions so they auto-apply on future rebases. This is powerful
but dangerous: a bad resolution gets cached and silently re-applied.

### Inspect before continuing

After every conflict resolution during a rebase, run:

```bash
git rerere diff
```

This shows what rerere will cache (or has auto-applied). Read it. If the resolution looks wrong, fix it before
continuing.

### Forget bad resolutions

If a resolution was cached incorrectly:

```bash
# Forget resolution for a specific file
git rerere forget <path>

# Nuclear option: forget ALL cached resolutions
git rerere forget .
```

### When starting a rebase over

If a rebase failed and you're retrying, **always clear affected rerere entries first:**

```bash
# List conflicted files from the failed rebase
git rerere forget .

# Then start the rebase fresh
git rebase --abort  # if still in progress
git reset --hard temp/pre-rebase-<branch>
git rebase <target>
```

Otherwise the bad resolutions from the failed attempt will silently replay.

---

## 8. Destructive Command Safety

### Never run without explicit user request

These commands rewrite history or discard work. Never run them autonomously:

| Command | Risk |
|---------|------|
| `git push --force` / `--force-with-lease` | Rewrites remote history |
| `git reset --hard` | Discards uncommitted work |
| `git checkout .` / `git restore .` | Discards all unstaged changes |
| `git clean -f` / `git clean -fd` | Deletes untracked files permanently |
| `git branch -D` | Force-deletes a branch |
| `git rebase` | Rewrites commit history |
| `git rebase --skip` | Drops a commit's changes entirely during rebase |
| `git rebase -i` | Interactive history rewriting - never use autonomously |
| `git filter-branch` / `git filter-repo` | Rewrites entire repository history |

### Safe alternatives

When you need to undo something, prefer non-destructive operations:

| Instead of | Use | Why |
|------------|-----|-----|
| `git reset --hard` | `git reset --soft HEAD~1` | Keeps changes staged for re-commit |
| `git checkout .` | `git stash push -m "description"` | Preserves changes, retrievable later |
| `git commit --amend` | `git commit --fixup=<sha>` | Creates reviewable separate commit |
| `git rebase -i` (to drop) | `git revert <sha>` | Additive, doesn't rewrite history |
| `git push --force` | Push to a new branch | Preserves the original remote state |

---

## 9. Recovery

When things go wrong, these are the escape hatches.

### reflog - the universal undo

`git reflog` shows every position HEAD has been at. It's your time machine:

```bash
git reflog

# Output looks like:
# abc1234 HEAD@{0}: rebase (continue): ...    ← current (possibly broken)
# def5678 HEAD@{1}: rebase (start): ...
# 789abcd HEAD@{2}: commit: ...               ← state before rebase
```

Find the entry before the bad operation and reset to it:

```bash
git reset --hard <reflog-sha>
```

### Safety branch rollback

If you followed the rebase protocol (section 4), the safety branch is your instant rollback:

```bash
git reset --hard temp/pre-rebase-<branch-name>
```

### Undo a bad amend

If someone (or you) already ran `--amend`:

```bash
git reflog
# Find the entry BEFORE the amend
git reset --soft HEAD@{1}
# Changes from the amend are now staged, original commit is restored
```

### Always inform the user

When using any recovery command, explain:
1. What went wrong
2. What state you're restoring to
3. What the user should verify after recovery

---

## Quick Reference

```
COMMIT
  ✗ git commit --amend        → git commit --fixup=<sha>
  ✗ git add . / git add -A    → git add <specific-files>
  ✗ amend review feedback      → git commit --fixup=<reviewed-sha>
  ✗ amend at rebase edit stop  → git commit --fixup=<sha>, then --continue
  ✓ git diff --staged          (review before every commit)
  ✓ git log --oneline -10      (match the user's conventions)

REBASE
  ✓ git branch temp/pre-rebase-<name>   (safety branch first)
  ✓ git status --porcelain              (must be clean)
  ✗ git checkout --theirs/--ours        → edit conflicts manually
  ✓ git rerere diff                     (inspect before --continue)
  ✓ git diff --stat temp/pre-rebase-*   (verify after rebase)

CONFLICT RESOLUTION
  ✓ Read all three sections (ours / base / theirs)
  ✓ Understand what each side changed relative to base
  ✓ Edit only the conflict region, remove all markers
  ✓ git diff -- <file>                  (verify resolution)
  ✗ Replace entire file with one side

DESTRUCTIVE OPS
  ✗ git push --force                    → ask user first, use --force-with-lease
  ✗ git reset --hard                    → git reset --soft HEAD~1
  ✗ git clean -f                        → git stash push -m "..."
  ✗ git branch -D                       → ask user first

RECOVERY
  ✓ git reflog                          (find the state before the mistake)
  ✓ git reset --hard temp/pre-rebase-*  (rollback to safety branch)
  ✓ git rerere forget <path>            (clear bad cached resolution)
```
