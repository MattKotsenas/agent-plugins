---
name: delve
description: >
  Guide a human reviewer through a chunked, screen-sized diff review.
  Collects feedback as actionable TODOs for downstream agents.
  USE THIS SKILL when the user wants to review code changes interactively.
---

# Delve — Interactive Diff Review

Walk a reviewer through a diff one cohesive chunk at a time. Collect comments as
structured TODOs that a downstream agent can act on.

---

## Phase 1: Choose Diff Baseline

**Always prompt the user to choose.** Suggest a default based on session history,
but never auto-select.

Present these options:

- **Merge base** — changes since the branch diverged from the merge target
  *(default if this is the first diff action in the session)*
- **Last session** — changes since the previous delve session
  *(default if a prior delve session exists)*
- **Last change** — uncommitted changes if any exist, otherwise the last commit
- **Custom ref** — user provides a base and/or head ref

After the user chooses, store the baseline in session state (see Phase 6).

### Resolving the baseline to git refs

| Choice       | base ref                                     | head ref     |
|--------------|----------------------------------------------|--------------|
| Merge base   | `git merge-base HEAD <target-branch>`        | `HEAD`       |
| Last session | stored ref from previous session             | `HEAD`       |
| Last change  | `HEAD` (if uncommitted) or `HEAD~1`          | working tree or `HEAD` |
| Custom ref   | user-provided                                | user-provided or `HEAD` |

If the target branch is unknown, ask the user. Common defaults: `main`, `master`,
or the repo's default branch.

---

## Phase 2: Acquire the Diff

1. Run `git diff --stat <base> <head>` to get the file-level summary.
2. For each changed file, run `git diff <base> <head> -- <file>` to get the
   full unified diff.
3. Parse each file diff into **atomic hunks**. A hunk is one contiguous block of
   changes (one `@@` section in unified diff format).
4. For every hunk, record metadata:
   - **file path**
   - **change type**: added / modified / deleted / renamed
   - **enclosing symbol**: the function, method, or class the hunk sits inside
     (read the `@@` context line and surrounding code to determine this)
   - **symbols referenced**: any functions, types, or variables that appear in
     the changed lines

Process files one at a time to keep context usage bounded. Store hunk metadata
as you go rather than holding every diff in context simultaneously.

---

## Phase 3: Plan the Chunk Order

Group and order hunks into **chunks** — each chunk is a set of related hunks
that the reviewer will see together on one screen.

### 3.1 Constraints (co-optimize all four)

1. **Screen fit** — a chunk should fit comfortably on one screen (~60 lines of
   diff). If a single hunk exceeds this, it becomes its own chunk.
2. **High cohesion** — group hunks that belong to the same logical change:
   same function, same module, same feature.
3. **Utility function placement**:
   - Show utility functions **first** if understanding them is required to
     comprehend later chunks.
   - Show utility functions **last** if they are self-evident or rarely called.
4. **Call flow** — prefer showing function implementations before their call
   sites. The reader should understand *what* a function does before seeing
   *where* it's used.

### 3.2 Heuristic: Build a Symbol Graph

1. From the hunk metadata, build a graph:
   - Nodes = symbols (functions, classes, methods) that were changed or
     referenced in changed lines.
   - Edges = call/reference relationships (implementation → call site).
2. Score each potential chunk grouping by:
   - **Cohesion**: how many hunks in the chunk share the same symbol or module.
   - **Dependency direction**: does the chunk show implementations before uses?
   - **Screen fit**: is the total diff size ≤ ~60 lines?
   - **Utility likelihood**: is this a standalone helper? (heuristic: small
     function, many callers, few dependencies)
3. Greedily assemble chunks that maximize the combined score.

### 3.3 Output: the Diff Plan

Store the ordered list of chunks with their hunk assignments. This is the
**Diff Plan** — the sequence the reviewer will walk through.

Show the user a brief overview before starting the review loop:
- Number of chunks
- Files covered
- Estimated review time (rough: ~1 min per chunk)

---

## Phase 4: Review Loop

Walk through the Diff Plan one chunk at a time.

### For each chunk:

1. **Display the chunk.**
   Show the unified diff for all hunks in this chunk. Include:
   - File path(s)
   - Enclosing symbol(s)
   - The diff itself (with syntax highlighting if the agent supports it)

2. **Prompt the user for an action:**
   - **Next** — advance to the next chunk
   - **Previous** — go back to the prior chunk
   - **Comment** — leave a review comment on this chunk

3. **If the user selects Comment:**
   - Collect the comment text from the user.
   - Create a TODO (see Phase 5).
   - After capturing the comment, prompt again (Next / Previous / Comment).
     The user can leave multiple comments on the same chunk.

4. **Navigation rules:**
   - Track the current chunk index.
   - "Previous" on the first chunk does nothing (tell the user they're at the
     start).
   - "Next" on the last chunk triggers completion (Phase 7).

---

## Phase 5: Capture TODOs

Every comment the reviewer leaves becomes a TODO for a downstream agent.

### TODO structure

Each TODO must include:

| Field              | Description                                                |
|--------------------|------------------------------------------------------------|
| **comment**        | The reviewer's comment, verbatim.                          |
| **file_path**      | File(s) the chunk covers.                                  |
| **symbol**         | Enclosing function/class/method name(s).                   |
| **excerpt**        | A short (3–5 line) excerpt of the relevant changed code.   |
| **content_anchor** | A content-based anchor: the first non-blank changed line   |
|                    | in the hunk. NOT a line number (those drift on rebase).    |

### Where to store TODOs (tiered — use the first available option)

1. **TodoWrite / built-in todo tool** — if the session has a todo or task
   creation tool, write each TODO there.
2. **External task tracker** — if a tool like Trekker is available, create
   issues/tasks there.
3. **Session file fallback** — write TODOs as a JSON array to a file in the
   session workspace (e.g., `delve-todos.json`).
4. **Context fallback** — if none of the above are available, output the TODO
   list directly in the conversation for the user to copy.

---

## Phase 6: Session State

Persist the following across the session so the review can be resumed or
referenced later.

| Key                | Value                                            |
|--------------------|--------------------------------------------------|
| `delve_baseline`   | The chosen baseline (type + resolved refs)       |
| `delve_head_ref`   | The HEAD ref at review start (for "last session")|
| `delve_plan`       | The ordered list of chunks with hunk assignments |
| `delve_position`   | Current chunk index                              |
| `delve_completed`  | Set of chunk indices the user has visited         |
| `delve_todos`      | List of TODOs with context anchors               |

### Storage strategy (tiered — use the first available option)

1. **SQL tool** — if available, create a `delve_state` table:
   ```sql
   CREATE TABLE IF NOT EXISTS delve_state (
     key   TEXT PRIMARY KEY,
     value TEXT
   );
   ```
   Store each key/value pair as a row. Values are JSON-encoded.

2. **Session file fallback** — write state as a single JSON file in the session
   workspace (e.g., `delve-state.json`).

At the **start of a new delve session**, check for existing state:
- If `delve_head_ref` exists from a prior session, offer it as the "Last
  session" baseline option.
- If `delve_plan` exists and the baseline hasn't changed, offer to resume
  the previous review from `delve_position`.

---

## Phase 7: Completion

When the user advances past the last chunk:

1. **Summarize the review:**
   - Total chunks reviewed
   - Number of TODOs captured
   - Files covered

2. **If TODOs exist**, offer to:
   - List all TODOs with their context anchors
   - Revisit a specific TODO's chunk
   - Hand off the TODO list to an implementation agent

3. **Update session state:**
   - Store the current HEAD as `delve_head_ref` so the next session can offer
     "changes since last session" as a baseline.

---

## Quick Reference

```
/delve
  1. Choose baseline  →  merge base / last session / last change / custom
  2. Acquire diff     →  git diff per file, parse into hunks
  3. Plan chunks      →  group by cohesion, order by call flow
  4. Review loop      →  display chunk → Next / Previous / Comment
  5. Capture TODOs    →  structured TODOs with content anchors
  6. Complete         →  summary + TODO handoff
```
