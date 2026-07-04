---
name: tuicr
description: Drive tuicr, the terminal code-review TUI, from a Copilot session. Use whenever the user wants to review changes together, says "let's review", "pull up the diff", "open tuicr", "review this PR in the terminal", or asks you to read back the comments they left. Centers on the `tuicr review` CLI to attach to a session, read the user's comments, and (when asked) add agent comments; when launching an interactive pane in psmux, split the agent's OWN pane, never the active window.
---

# tuicr Review Workflow

tuicr is a terminal code-review TUI. It has two halves, and you use both:

- The **TUI** is where the *human* reads the diff and writes comments. You do not drive it - it is theirs.
- The **`tuicr review` CLI** is your interface. It lists sessions, reads the human's comments, and can add
  agent-authored comments - all without opening the TUI. Prefer it for everything you do.

There is no push stream from tuicr to you. You read comments by running the CLI on demand. This skill covers the
review workflow; for the full flag surface of any command, run `tuicr --help` or `tuicr <command> --help`.

The examples below use Windows paths, PowerShell, and **psmux** (a tmux clone; on some setups `tmux` is psmux). Adapt paths, quoting, and multiplexer commands to your own shell and multiplexer.

## First, pick the workflow

The right behavior depends on whose review it is. Decide before doing anything; if it is ambiguous, ask.

1. **User-led review of your changes** (the common case). The user inspects a patch you produced and writes
   comments. Your job: find or open the session, then read their comments with `tuicr review comments` when they
   say they are ready. Do **not** add your own comments, pre-review your own patch, or impersonate the user.

2. **Agent review of a patch.** The user wants you to critique a patch. You may inspect it and, once you have
   confirmed the target session, record findings with `tuicr review add --username <you>`. Ask first if the
   session or intent is unclear.

## Attach to a session

The TUI writes a persisted session file the moment a review target becomes active, so you can attach while it is
open. List sessions and let the JSON tell you which is live:

```powershell
tuicr review list --repo .           # this checkout's local sessions + its origin repo's PR sessions
tuicr review list --repo owner/repo  # all sessions for a forge repo (finds PR sessions from anywhere)
tuicr review list --all              # every session across all repos, when you don't know the repo
$sessions = tuicr review list --repo . | ConvertFrom-Json
$live = $sessions | Where-Object active     # the currently-open TUI session(s)
```

Each row carries a `slug`, a `kind` (`local` or `pr`), and an `active` flag. Choose the session by:

- exactly one `active` session -> attach to it;
- multiple active, or none clearly right -> ask the user which `slug`;
- a PR review -> pass the PR slug (e.g. `gh:owner/repo/pr/42`) to `--session`. PR slugs are self-contained and
  need no `--repo`.

`active` is a convenience signal, not a guarantee. If slug resolution fails, ask the user for the slug or repo path.

**How you reference a chosen session** in `comments`/`add` depends on its kind - each listing row gives both a
`slug` and a `path`:

- git working-tree or commit-range session -> the `slug`, plus `--repo <checkout>` when the slug is `local`.
- PR session -> the `slug` alone; it is self-contained and needs no `--repo`.
- `--file` / no-VCS session -> the session **`path`** (the `.json` from the listing). These slugs are not
  repo-resolvable, so the path is the only reliable reference.

## Read the user's comments (the main loop)

After the user says comments are ready, or after the TUI exits, read them:

```powershell
# git session: the slug (add --repo when the slug is `local`)
$comments = tuicr review comments --repo . --session <slug> | ConvertFrom-Json
# --file / no-VCS session: pass the session .json path from `review list`
$comments = tuicr review comments --session <path-from-list> | ConvertFrom-Json
```

Each comment carries `id`, `path`, `start_line`/`end_line`, `side`, `comment_type`, `lifecycle_state`, and
`content`. Treat `comment_type` as the marching order:

- `issue` - a blocking problem; fix it first.
- `suggestion` - implement it, or explain why not.
- `note` - answer or acknowledge.
- `praise` - no action needed.

If you are waiting during a live review, poll this command roughly every 30 seconds and diff the `id`s against the
previous result to spot new comments. Read immediately when the user says they are done, and stop polling then so
you are not blocking other work. If the result is empty, confirm you selected the session they actually saved into.
Before you claim the work is complete, re-run `tuicr review comments` - the user may have added more while you worked.

## Add agent comments (only when appropriate)

Only in the agent-review workflow, and only after the user is happy for you to write into tuicr. Pass `--username`
so your comments are visually distinct from theirs.

```powershell
tuicr review add --session <slug> --target-file src/main.rs --line 42 --side new --type issue --username "Copilot" "Handle the empty case here."
```

- Omit `--target-file` for a review-level (whole-review) comment; use it alone for a file-level comment.
- Add `--line <n>` for a line comment, `--end-line <n>` for a range. Use `--side old` for removed lines,
  `--side new` for added or unchanged lines.
- For structured input, pass `--input` with literal JSON, `@path\to\file.json`, or `-` for stdin. PowerShell has no
  heredoc, so pipe a string: `'{ "type": "issue", "content": "...", "file": "src/main.rs", "line": 42 }' | tuicr review add --session <slug> --input -`.

## Launch a review pane (psmux) - split YOUR OWN pane

When the user needs an interactive pane and none is open, the pane must land **next to the Copilot session that is
launching it** - not wherever the user happens to be looking. This is the mistake to avoid: `tmux split-window`
with no target splits the *active* pane, which drifts as the user navigates. Your own pane is stable and lives in
`$env:TMUX_PANE`; always target it, and split it side-by-side with `-h` so the review and your session stay readable.

```powershell
# Correct: split the agent's own pane SIDE-BY-SIDE (-h), capture the new pane id.
$pane = tmux split-window -t $env:TMUX_PANE -h -d -P -F '#{pane_id}' -l 65% -c C:\path\to\repo 'tuicr -w'
# Wrong: `tmux split-window ...` with no -t  -> lands in whatever window is active.
# `-h` = side-by-side (left/right); omit it and you get a top/bottom stack.
```

Run `tuicr` as the pane command directly, as shown. Avoid wrapping it in `pwsh -Command "..."`: that loads the
interactive profile (prompt, module imports) the review pane never needs, and a heavy profile can stall or hang
before `tuicr` starts. If a compound command forces you through pwsh, pass `-NoProfile`.

Then attach with `tuicr review list --repo C:\path\to\repo` to capture the slug, and enter the read loop above.
tuicr waits for the human, so allow a long timeout (~10 min) if your tool blocks on the command.

If a reliable auto-split is not available in your setup, fall back cleanly: tell the user you are waiting for them
to start `tuicr` in the target repo, then attach with `tuicr review list` once they say it is up. Never silently
split the active pane as a workaround - a review pane in the wrong window is the exact failure this section prevents.

## Environment notes

- `tuicr` installs via `cargo install tuicr`; config lives at `%APPDATA%\tuicr\config.toml` (theme, diff view, etc.).
- The `tuicr review` CLI works with or without a multiplexer - you do not need psmux just to read an existing session.
- Exports: inside the TUI the user can `:submit` to GitHub/GitLab or `y` to copy a structured markdown block. If they
  paste that block instead of using the CLI, honor it - but the CLI is the primary, most reliable source of feedback.

## When not to use tuicr

- The user only wants raw `git diff` output.
- The user wants an inline, chunked, agent-narrated diff walkthrough rather than an external review TUI.
- The task is a remote PR review with no tuicr session involved.
