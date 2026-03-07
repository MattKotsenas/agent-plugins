# prune

Interactive branch cleanup for git repositories.

Scans all local and remote branches, categorizes them by status (merged PR,
renamed, active PR, abandoned, unknown), and presents a structured review
for the user to approve before deleting anything.

## Features

- **Squash-merge aware** — uses PR-based verification when `git branch --merged`
  misses squash-merged branches
- **Rename detection** — finds old branch names by comparing SHAs
- **Safe by default** — always presents for review before deleting
- **Undo commands** — every deletion includes the SHA to restore the branch
- **Fork-friendly** — distinguishes between upstream and origin remotes

## Usage

Invoke the `prune` skill when you want to clean up branches:

> Clean up my stale branches
>
> Which branches can I delete?
>
> Tidy up my git repo

## Requirements

- Git CLI
- One of: GitHub MCP tools, Azure DevOps MCP tools, `gh` CLI, or `az` CLI
  (for PR status lookup; gracefully degrades without any of them)
