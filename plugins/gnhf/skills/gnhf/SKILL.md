---
name: gnhf
description: >
  Good Night, Have Fun. Make ONE provably-correct, complexity-reducing change
  on a fresh branch off the default branch, then stop. USE THIS SKILL when the
  user types /gnhf, asks for a single low-risk independently-reviewable
  improvement, mentions "overnight" or "unattended" code work, wants to wrap
  autopilot around a bounded single-iteration prompt, or asks for one small
  provable cleanup that should be isolated on its own branch. Do NOT use this
  skill for broad cleanup, fix-all-tests sweeps, multi-file modernization,
  exploratory refactoring, or anything the user expects to span more than one
  reviewable branch.
---

# gnhf — Good Night, Have Fun

Inspired by [gnhf](https://github.com/kunchenguid/gnhf), but stripped down:
one prompt, one change, one branch, then stop. No loop, no orchestration.
To run overnight, wrap this in `autopilot` or an external scheduler that
invokes `/gnhf` repeatedly — every invocation produces an independent,
reviewable branch.

**In one line:** find one provably-incorrect thing, fix it provably, reduce
complexity, commit on its own branch, and document *what*, *why*, and *how
proved* in the message.

The structure is six phases. Each phase has a single job. Order matters:
**discover before you branch**, so a refusal never leaves stray branches.

---

## Phase 1 — Preflight

Establish a known-good starting point.

1. Confirm the repo has commits: `git rev-parse HEAD` succeeds. An empty
   repo has nothing to branch from.
2. Fetch if `origin` is configured: `git fetch origin --quiet`. This must
   happen before reading `origin/HEAD`, which can otherwise be stale.
3. Identify the default branch, in order:
   - `git symbolic-ref --short refs/remotes/origin/HEAD` if set
   - first of `origin/main`, `origin/master`, `origin/dev` that exists
   - first of local `main`, `master`, `dev` that exists
   - else stop and report.
4. Detect worktree mode: `git worktree list` shows more than one
   worktree. In worktree mode, the skill creates an additional worktree
   for this iteration instead of switching the current worktree's branch.
5. Prepare the launch point:
   - Branch mode: this iteration runs in the current working tree, so
     its state matters. If `git status --porcelain` is non-empty, stop
     and report — stashing the user's work-in-progress would obscure
     what changed in this iteration. If the current branch matches
     `refactor/gnhf-*`, switch to the default branch first to prevent
     accidental stacking when `/gnhf` is re-invoked back-to-back.
   - Worktree mode: no preparation needed. Phase 4 step 3 creates a
     fresh worktree from `<default-ref>` regardless of the invoking
     directory or branch, so `/gnhf /gnhf` simply produces two
     parallel worktrees.

---

## Phase 2 — Discover a provable target

Find ONE thing that is **provably incorrect** AND that you can **provably
fix**. "Provable" means a reviewer can verify the claim from the diff plus
a bounded set of existing repo-standard validation commands (test, build,
lint, docs build) or a cited static query.

Acceptable target categories:

- **Wrong test assertion** — cite the spec or code under test the assertion
  should match.
- **Documented invariant violation** — cite the doc and the violating code.
- **Reproducible bug** — write a failing test first, then make it pass.
- **Dead private code** — a *private/local* symbol unreferenced anywhere in
  the repo (sources, tests, docs, scripts, config, generated entry points).
  Cite the exact query (`rg`, LSP `findReferences`, etc.).
- **Typo in a public identifier** that breaks docs links, imports, or CLI
  command names — cite the broken consumer.
- **Hard-coded value contradicting a constant defined elsewhere** — cite
  both sites.
- **Drifted duplicate definition** — cite both copies and identify the
  source of truth.
- **Bespoke implementation that duplicates a standard-library or
  well-known-dependency capability** — cite the equivalence (signature,
  semantics, accepted inputs, failure behavior). This category is the
  trickiest: the substitution is one idea *only when* the old behavior's
  required semantics are known and matched. If the bespoke code accepted
  extra cases, performed recovery, logged differently, or normalized data
  differently, each divergence is an additional idea unless proved
  irrelevant — at which point it's no longer a single-iteration target.

Subjective targets are out: "could be clearer", "feels complex", "more
idiomatic", "better name", "modernize". Reaching for these words means the
target isn't provable. The reviewer can't verify a feeling, which is why
this gate exists.

Some categories are off-limits as "dead code" no matter what grep returns:
public/exported API, routes, migrations, serialized field names, config
keys, plugin or extension hooks, framework entry points, reflection
targets, anything reached by DI. These can be invoked through paths grep
can't see. Refuse rather than guess.

---

## Phase 3 — Review-cost check

Review cost is **cognitive complexity**, not line count. A 500-line diff
that mechanically replaces a hand-rolled parser with `JSON.parse` is one
idea: cheap to review. A 30-line diff that introduces a new conditional
branch and a new invariant is three ideas plus interactions: expensive to
review despite being smaller.

Borrowed from G. Ann Campbell's *Cognitive Complexity: A new way of
measuring understandability* (SonarSource, 2017): **sequence is free,
nesting and structural disruption are not.** Apply that lens to the
candidate diff, not the source code.

### One-idea rule (operational checklist)

A candidate has cognitive payload ≤ 1 only if **all** of the following are
true. If any is false, the target is too big — pick something smaller.

1. **One root defect** is being fixed.
2. **One semantic transformation** explains the entire diff.
3. **One bounded proof obligation** validates the change (one validation
   surface, even if it's a small set of repo-standard commands).
4. **No net-new** independent branch, invariant, dependency, error path,
   or behavior mode is introduced.
5. The cognitive payload can be stated in **one sentence without "and"**.

Strip mechanical chunks from the diff before counting — these cost the
reviewer nothing once the single idea behind them is verified:

- Renames of a single symbol across many call sites.
- Mechanical replacements of `old_call(...)` with `new_call(...)` under a
  uniform substitution rule.
- Type substitutions with identical semantics.
- Removals proved by a single "this is unreachable" citation.
- Identical call-site changes after extracting one helper.

What remains is the cognitive payload. Count its distinct ideas.

### Concept-count, not abstraction-count

A new abstraction is allowed when it **collapses** duplicated existing
behavior into one named concept — net concept count goes down even though
one new symbol exists. A new abstraction is out of scope when it **adds**
a layer, extension point, strategy, interface, or "flexibility" mechanism
not required to remove the proven defect.

Net-new lines are allowed for: a regression test that reproduces the bug,
a comment that prevents the same mistake, a configuration entry the fix
forces, or a single extracted helper that consolidates real duplication.

### Audit-cost backstop

For diffs dominated by mechanical chunks, the reviewer must still confirm
the mechanical part is uniform. The proof obligation expands accordingly:

- The proof must cover **all** affected sites with a **bounded, repo-standard
  command set** — full test suite, full build, full lint, or the small set
  of validators the repo conventionally uses (e.g., in a monorepo, the
  command(s) that exercise each touched package). Per-file manual checks
  are not enough.
- If different affected areas require different normal validators, list
  all of them in the commit message and state which paths each covers.
- If no bounded command set covers all affected sites, the diff is too
  risky even when the idea is simple.

---

## Phase 3.5 — Candidate statement

Before branching, write down a candidate statement. This is the audit
trail for the one-idea contract; refuse rather than fudge it.

```
Target:
  <one provably incorrect thing>

Evidence:
  <citation, query result, or failing test showing it is incorrect>

One idea:
  <single semantic transformation, one sentence, no "and">

Mechanical chunks:
  <"none", or describe the uniform replication rule>

Proof:
  <bounded repo-standard command set covering all affected sites>
```

If you can't fill every slot, the target isn't ready. Refuse.

---

## Phase 4 — Branch and execute

Only now create the branch.

1. Pick a slug: short kebab-case description of the change (≤40 chars, no
   issue or PR numbers, no dates). Examples: `replace-uuid-rng-with-stdlib`,
   `inline-single-use-formatter`, `correct-foo-typo-in-readme-anchors`.
2. Collision suffix: if `refactor/gnhf-<slug>` already exists locally or on
   `origin`, append a 4-char suffix derived from the target path or symbol
   (stable across re-runs, not random): e.g.
   `refactor/gnhf-replace-uuid-rng-with-stdlib-a1b2`.
3. Create the workspace for this iteration:

   - **Branch mode:**

     ```
     git switch -c refactor/gnhf-<slug> <default-ref>
     ```

   - **Worktree mode:** pick `<wt-path>` by mirroring the user's existing
     worktree layout — read `git worktree list` to infer (sibling
     directories, `.worktrees/` sub-dir, etc.). If no clear pattern
     emerges, use `../<repo-name>-gnhf-<slug>` as a sibling directory.
     Then:

     ```
     git worktree add <wt-path> -b refactor/gnhf-<slug> <default-ref>
     cd <wt-path>
     ```

     All subsequent steps run inside `<wt-path>`.

4. Make the change. Smallest diff that fixes the target.
5. Prove it using the proof set declared in Phase 3.5:
   - **Behavioral change:** run the declared validators. They must pass.
   - **Dead code removal:** re-run the citation query on the new tree to
     show zero references, plus the declared build/lint.
   - **Typo / contradiction / drifted duplicate:** run the declared
     build/docs build to show the citation chain resolves consistently.
   - **Bespoke → standard substitution / helper extraction:** run the
     declared full test/build/lint set (the audit-cost backstop) and
     re-check that cognitive payload is still one idea against the
     candidate statement.
6. If anything unrelated breaks, or proof can't be produced, clean up and
   refuse. "Fixing the fallout" adds new ideas to the diff and violates
   the one-idea rule — abandon and pick a different target.

   - **Branch mode:**

     ```
     git reset --hard <default-ref>
     git switch <default-branch>
     git branch -D refactor/gnhf-<slug>
     ```

   - **Worktree mode:** step out of `<wt-path>` first (e.g. back to the
     main worktree), then:

     ```
     git worktree remove --force <wt-path>
     git branch -D refactor/gnhf-<slug>
     ```

   Then report the refusal.

---

## Phase 5 — Commit, then stop

Commit on the branch using this message structure:

```
<one-line summary, imperative mood>

What changed:
  <1-3 lines describing the diff>

Why it was incorrect:
  <1-3 lines citing the evidence>

How this is proved correct:
  <the exact command(s) a reviewer can re-run>
```

If the diff touches more than 3 files, or contains any uniform
replication pattern (rename, mechanical substitution, helper extraction
applied at multiple call sites), append this section. It tells the
reviewer where to focus and where to trust the proof:

```
Cognitive payload:
  <the single non-mechanical idea, one sentence, no "and">
Mechanical chunks:
  <what was replicated, plus the audit command(s) covering all of them>
```

Then stop:

- **Do not push.** Pushing breaks the user-controlled review boundary.
- **Do not open a PR.** The user opens PRs themselves so they can verify.
- **Do not amend, rebase, or squash.** History rewrites are the user's
  call, not the skill's.
- **Do not start a second iteration in the same turn.** If the caller
  wants another change, it will invoke `/gnhf` again — and that invocation
  will branch fresh from the default. Stacking iterations breaks the
  one-branch-per-change contract that makes this skill safe to wrap in
  autopilot.

---

## Phase 6 — Report

End with a short report:

- Branch name
- Commit SHA (short)
- Proof command(s) the reviewer can re-run
- One sentence: what made this target provable
- One sentence: what the cognitive payload was (the one idea)

Nothing else. No follow-up suggestions — those compound across iterations
and erode the one-change contract.

---

## When to refuse

Refuse this iteration if any of these hold. If you already branched, clean
up as in Phase 4 step 6 before refusing.

- Branch mode is active and the current worktree is dirty.
- The repository has no commits.
- No default branch can be identified.
- After a reasonable scan, no candidate satisfies Phase 2.
- The candidate fails any clause of the one-idea checklist (Phase 3).
- No bounded repo-standard proof set covers all affected sites.
- The only candidates require subjective judgement.
- A behavioral change is needed but the repository has no existing
  test/lint/build/docs command to use as proof.

Refusing is success. A clean refusal beats a marginal change because a
marginal change wastes a reviewer's most expensive resource: attention.
