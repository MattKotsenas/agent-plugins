---
name: delve
description: >
  Guide a human reviewer through a chunked, screen-sized diff review. Collects feedback as actionable TODOs for
  downstream agents. Use this skill when the user wants to review code changes, walk through a diff, do a code review,
  look at what changed, or inspect a PR - even if they don't say "delve" explicitly. Also use when the user says
  "review my changes", "what did I change", "let's go through the diff", or similar.
---

# Delve - Interactive Diff Review

Walk a reviewer through a diff one cohesive chunk at a time. Collect comments as structured TODOs that a downstream
agent can act on.

The core idea: a `diff-split.cs` tool handles all the mechanical work of splitting diffs into screen-sized chunk files.
Your role is to resolve git refs, run that tool, decide presentation order from metadata, and guide the reviewer through
each chunk. This separation exists because LLMs are unreliable at counting lines and enforcing size constraints, while
tools are deterministic and exact.

---

## Phase 1: Choose Diff Baseline

Prompt the user to choose a baseline. Suggest a default based on session history, but let them pick.

- **Merge base** - changes since the branch diverged from the merge target
  *(default if this is the first diff action in the session)*
- **Last session** - changes since the previous delve session
  *(default if a prior delve session exists)*
- **Last change** - uncommitted changes if any exist, otherwise the last commit
- **Custom ref** - user provides a base and/or head ref

Store the baseline in session state (see Phase 5).

### Resolving the baseline to git refs

| Choice       | base ref                                     | head ref     |
|--------------|----------------------------------------------|--------------|
| Merge base   | `git merge-base HEAD <target-branch>`        | `HEAD`       |
| Last session | stored ref from previous session             | `HEAD`       |
| Last change  | `HEAD` (if uncommitted) or `HEAD~1`          | working tree or `HEAD` |
| Custom ref   | user-provided                                | user-provided or `HEAD` |

If the target branch is unknown, ask the user. Common defaults: `main`, `master`, or the repo's default branch.

---

## Phase 2: Split the Diff

Run the `diff-split.cs` tool to split the diff into chunk files. The tool is at `tools/diff-split.cs` relative to
this skill's plugin directory (e.g., `~/.copilot/installed-plugins/agent-plugins/delve/tools/diff-split.cs`).

This is a .NET 10 file-based app - invoke it with `dotnet run <path-to-file.cs>`. The `--` separator is required to
pass arguments to the app rather than to `dotnet run` itself.

```
dotnet run <path-to-diff-split.cs> -- \
  --base <base-ref> \
  --head <head-ref> \
  --max-lines 40 \
  --output-dir <session-dir>
```

The tool writes numbered `.diff` files and prints a JSON manifest to stdout:

```json
{
  "base": "abc123",
  "head": "def567",
  "max_lines": 40,
  "output_dir": "/path/to/session-dir",
  "chunks": [
    {
      "index": 0,
      "file": "delve-chunk-00.diff",
      "lines": 35,
      "oversized": false,
      "path": "src/auth/token.ts",
      "old_path": null,
      "change_type": "modified",
      "binary": false,
      "hunk_headers": ["@@ -10,6 +10,12 @@ function validateToken"],
      "hunk_count": 2
    }
  ]
}
```

Store the manifest in session state. If the tool exits non-zero, report the stderr to the user and stop.

The tool guarantees chunks never cross file boundaries and stay within the line limit (except single oversized hunks,
which are flagged). This means you never need to parse diffs, count lines, split hunks, or validate sizes yourself -
attempting to do so would bypass the guarantees the tool provides.

---

## Phase 3: Order the Chunks and Present the Plan

Decide the presentation order using only the manifest metadata. The goal is presentation quality - showing the reviewer
things in an order that helps them understand the change - not precise dependency analysis.

Reading the `.diff` files during ordering wastes context on raw diff text when the manifest already has the signals you
need (file paths, change types, hunk headers with function names).

### Ordering heuristic

Apply these rules in priority order. When no rule provides a clear signal, preserve the tool's original order (which is
already grouped by file).

1. **New files before their consumers.** If a chunk has `change_type: "added"` and other chunks reference symbols
   matching the new file's name, show the new file first. The reviewer should understand what a thing does before seeing
   where it's used.
2. **Group by module.** Chunks from the same directory should be adjacent.
3. **Config and docs last.** Chunks for config files, READMEs, or documentation go at the end unless they are the
   primary change. These are supporting context, not the core logic.

**Example:** Given chunks for `TokenValidator.cs` (modified), `LoginService.cs` (modified, hunk header references
TokenValidator), `TokenClaims.cs` (added), `auth.json` (modified), `README.md` (modified) - a good order would be:
TokenClaims (new type) -> TokenValidator (core logic) -> LoginService (consumer) -> auth.json -> README.md.

### Show the Diff Plan

Present the ordered plan to the user:

```
Diff Plan

| #  | File                      | Type     | Lines |
|----|---------------------------|----------|-------|
| 1  | src/auth/TokenClaims.cs    | added    | 9     |
| 2  | src/auth/TokenValidator.cs | modified | 35    |
| 3  | src/auth/LoginService.cs   | modified | 28    |
| 4  | config/auth.json           | modified | 13    |
| 5  | README.md                  | modified | 11    |

5 chunks - 5 files - ~3 min
```

---

## Phase 4: Review Loop

Walk through chunks in the presentation order. All chunk files are pre-generated, so no shell commands are needed here.
Creating external viewer scripts or terminal panes would break the review flow - the user expects to stay in this
conversation.

### For each chunk:

1. **Display the chunk** using `show_file`:
   - Normal chunks (`oversized: false`):
     ```
     show_file(path: "<output_dir>/<file>")
     ```
   - Oversized chunks (`oversized: true`): show all pages back-to-back before prompting. The reviewer shouldn't have
     to ask to see the rest - that's easy to miss when it's buried in the comment form.
     ```
     show_file(path: "<output_dir>/<file>", view_range: [1, 40])
     show_file(path: "<output_dir>/<file>", view_range: [41, 80])
     ...until the file is fully shown
     ```

2. **Prompt the user** with `ask_user`. Comment comes first so the reviewer can capture thoughts while the diff is
   fresh, then decide navigation. Fields render in property order, so keep `comment` above `action`.
   ```json
   {
     "message": "Chunk N/M: <file path> - <hunk_headers summary>",
     "requestedSchema": {
       "properties": {
         "comment": {
           "type": "string",
           "title": "Comment (optional)",
           "description": "Leave feedback on this chunk. Each submission = 1 TODO."
         },
         "action": {
           "type": "string",
           "title": "Action",
           "enum": ["Next", "Comment & stay", "Previous", "Done"],
           "enumNames": ["Next →", "💬 Comment & stay", "← Previous", "Done ✓"],
           "default": "Next"
         }
       },
       "required": ["action"]
     }
   }
   ```

3. **Process the response:**
   - If `comment` is provided: create a TODO (see below).
   - **Next**: advance to the next chunk. After leaving one or more comments, flip the default to "Next".
   - **Comment & stay**: capture the TODO and re-display the same chunk's form.
   - **Previous**: go back one chunk. On the first chunk, tell the user they are at the start.
   - **Done**: skip to Phase 6.
   - If the user **declines** the form: treat as "Next" with no comment.

4. **"Next" on the last chunk** triggers completion (Phase 6).

### TODOs

Every comment becomes a TODO with enough context for a downstream agent to act on it without re-reading the full diff.

| Field              | Description                                                   |
|--------------------|---------------------------------------------------------------|
| **comment**        | The reviewer's comment, verbatim.                             |
| **file_path**      | File the chunk covers (from manifest `path`).                 |
| **hunk_headers**   | The `hunk_headers` from the manifest for this chunk.          |
| **content_anchor** | First non-blank changed line in the chunk (read from the      |
|                    | `.diff` file when creating the TODO). Content-based, not line |
|                    | numbers, because line numbers drift on rebase.                |

Store TODOs using the SQL tool if available (`delve_todos` table), otherwise write to
`<session-dir>/delve-todos.json`, otherwise output in the conversation.

---

## Phase 5: Session State

Persist state so the review can be resumed later.

| Key                | Value                                            |
|--------------------|--------------------------------------------------|
| `delve_baseline`   | The chosen baseline (type + resolved refs)       |
| `delve_head_ref`   | HEAD ref at review start (for "last session")    |
| `delve_manifest`   | The full manifest JSON from diff-split           |
| `delve_order`      | The presentation order (list of chunk indices)    |
| `delve_position`   | Current position in the presentation order       |
| `delve_todos`      | List of TODOs with content anchors               |

Use the SQL tool if available:
```sql
CREATE TABLE IF NOT EXISTS delve_state (key TEXT PRIMARY KEY, value TEXT);
```
Otherwise write to `<session-dir>/delve-state.json`.

At the start of a new delve session, check for existing state. If `delve_head_ref` exists from a prior session, offer
"Last session" as a baseline option. If `delve_manifest` exists and the baseline hasn't changed, offer to resume from
the previous position.

---

## Phase 6: Completion

When the user advances past the last chunk:

1. Summarize: chunks reviewed, TODOs captured, files covered.
2. If TODOs exist, offer to list them, revisit a specific chunk, or hand off to an implementation agent.
3. Store the current HEAD as `delve_head_ref` for next session.

---

## Quick Reference

```
/delve
  1. Choose baseline  →  prompt user for merge base / last session / last change / custom
  2. Split diff       →  run diff-split.cs tool, capture manifest
  3. Order chunks     →  reorder using manifest metadata only, show Diff Plan
  4. Review loop      →  show_file chunk → ask_user → capture TODOs → repeat
  5. Complete         →  summary + TODO handoff
```
