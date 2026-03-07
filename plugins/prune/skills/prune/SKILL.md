---
name: prune
description: >
  Catalog, verify, and clean up stale git branches. Supports squash-merge
  workflows. USE THIS SKILL when the user wants to clean up old branches,
  find stale branches, or tidy their git repo.
---

# Prune — Interactive Branch Cleanup

Scan all branches, categorize by status, present for review, and delete
approved branches.

---

## Phase 1: Detect Repository Layout

Auto-detect the upstream remote and target branch, then confirm with the user.

### 1.1 Find the upstream remote

Run `git remote -v` and look for:
1. A remote named `upstream` — common for fork workflows
2. If no `upstream`, check if `origin` points to the canonical repo (not a fork)
3. If ambiguous, ask the user which remote is the upstream source of truth

### 1.2 Find the target branch

Run `git remote show <upstream>` or check for common default branches:
- `main`, `master`, `dev` (in that order of preference)
- Or read from `git symbolic-ref refs/remotes/<upstream>/HEAD`

### 1.3 Confirm with user

Present the detected upstream remote and target branch. Ask the user to
confirm or override. Example:

> Detected upstream: `upstream` → `akkadotnet/akka.net`, target branch: `dev`
> Is this correct?

---

## Phase 2: Scan Branches

### 2.1 Fetch latest

```
git fetch <upstream> --quiet
git fetch origin --prune --quiet
```

### 2.2 Enumerate all branches

Run `git branch -vv --no-color` to get all local branches with:
- Branch name
- Short SHA
- Tracking remote (if any)
- Ahead/behind status
- Last commit subject

Also run `git branch -r --no-color` to get remote branches on `origin`
(excluding upstream branches — those aren't ours).

### 2.3 Collect metadata

For each branch, record:
- **name**: branch name
- **sha**: short SHA of the tip commit
- **tracking**: which remote branch it tracks (if any)
- **has_local**: whether a local branch exists
- **has_remote**: whether `origin/<name>` exists
- **last_commit_subject**: the commit message of the tip
- **is_current**: whether it's the currently checked-out branch

Skip tracking branches (`dev`, `main`, `master`) — never suggest deleting these.

---

## Phase 3: Categorize Each Branch

For each non-tracking branch, determine its category. Try these checks
**in order** — the first match wins.

### 3.1 Check: Is it the current branch?

If `is_current` is true, category = **current** (never delete).

### 3.2 Check: Is it a rename of another branch?

Compare the SHA against all other branches. If another branch has the
**exact same SHA** and a different name, this is likely an old name.

Category = **renamed** if:
- Same SHA as another branch
- The other branch has a remote tracking branch or an open PR
- This branch does NOT have a remote tracking branch or open PR

Record which branch it was renamed to.

### 3.3 Check: Is it merged upstream?

**Step A — Try `git branch --merged`:**

```
git branch --merged <upstream>/<target>
```

If the branch appears in this list, it was merged (not squash-merged).
Category = **merged**.

**Step B — Try PR-based verification (for squash merges):**

If the branch was NOT in the `--merged` list, check if it has a merged PR.

Use available tools to search for PRs from the branch. Try these in order:
- **GitHub MCP tools** — search for PRs with the branch name as head ref
- **Azure DevOps MCP tools** — search for PRs with the branch as source ref
- **`gh` CLI** — `gh pr list --head <branch-name> --state merged --json number`
- **`az` CLI** — `az repos pr list --source-branch <branch-name> --status completed`
- If none are available, skip PR-based verification (see Error Handling)

If a merged PR is found, verify the squash commit exists on the target branch:

```
git log --oneline <upstream>/<target> --grep="#<pr-number>" -1
```

If found, category = **merged**. Record the PR number.

**Step C — No merged PR found:**

Continue to next check.

### 3.4 Check: Does it have an open PR?

Search for open PRs from this branch using available tools (GitHub MCP,
Azure DevOps MCP, `gh` CLI, or `az` CLI — same priority as step 3.3B).

If found, category = **active_pr**. Record the PR number.

### 3.5 Fallback: Unknown

If none of the above matched, category = **unknown**.

---

## Phase 4: Present for Review

Group branches by action and present using a card-per-branch format.

### Output format

```
DELETE (<count> branches)
═════════════════════════

  Merged PRs (local + origin)
  ───────────────────────────

  ✓ <branch-name>
    PR #<number> merged │ <sha>
    ├─ delete: git branch -D <branch-name>
    ├─ delete: git push origin --delete <branch-name>
    └─ undo:   git branch <branch-name> <full-sha>

  Renamed (old names)
  ───────────────────

  → <old-branch-name>
    Renamed to <new-branch-name> │ <sha>
    ├─ delete: git branch -D <old-branch-name>
    └─ undo:   git branch <old-branch-name> <full-sha>


UNKNOWN (<count> branches — need your input)
════════════════════════════════════════════

  ? <branch-name>
    No PR found │ local only │ <sha>
    Last commit: "<commit subject>"


KEEPING (<count> branches)
══════════════════════════

  ● <branch-name>    PR #<number> open
  ─ dev
  ─ master
```

### Presentation rules

1. **DELETE section first** — this is what the user is here for
2. **Group within DELETE** by sub-category: merged PRs, abandoned, renamed
3. **For each deletable branch** show:
   - Status icon: ✓ (merged), ✗ (abandoned), → (renamed)
   - Why it's safe to delete (PR number, rename target)
   - Exact delete commands (local + remote if applicable)
   - Exact undo command (git branch from SHA)
4. **UNKNOWN section** — branches where the skill couldn't determine status.
   Show the last commit subject to help the user decide.
5. **KEEPING section** — brief, one line per branch. Just so the user can
   verify nothing was miscategorized.
6. **Use `-D` (force)** for delete commands, not `-d`, because squash-merged
   branches won't be detected as merged by git.

---

## Phase 5: Confirm and Execute

### 5.1 Ask for approval

After presenting the view, ask the user which branches to delete:
- "Delete all in the DELETE section?"
- "Delete all + some/all unknowns?"
- "Let me pick individually"

### 5.2 Execute deletions

For approved branches:

1. Switch to a safe branch first if the current branch is being deleted
   (switch to the target branch, e.g., `dev`)
2. Delete local branches: `git branch -D <name>`
3. Delete remote branches: `git push origin --delete <name>`
4. Report each deletion result (success/failure)

### 5.3 Post-cleanup

Run `git fetch origin --prune` to clean up stale remote tracking refs.

Report final state: how many branches remain.

---

## Error Handling

- **PR tools unavailable**: If no GitHub MCP, Azure DevOps MCP, `gh` CLI,
  or `az` CLI is available, skip PR-based verification. Categorize all
  non-`--merged` branches as **unknown** and note that PR status couldn't
  be checked.
- **Remote deletion fails**: Report the error but continue with remaining
  deletions. The branch may have already been deleted (e.g., by GitHub's
  auto-delete on merge).
- **Current branch in delete list**: Switch to target branch first. If the
  switch fails, skip that branch and report the error.

---

## Quick Reference

```
/prune
  1. Detect repo layout  →  find upstream remote + target branch
  2. Scan branches       →  enumerate local + remote, collect metadata
  3. Categorize          →  merged / renamed / active PR / unknown
  4. Present             →  card-per-branch grouped by action
  5. Confirm + execute   →  user approves, delete local + remote
```
