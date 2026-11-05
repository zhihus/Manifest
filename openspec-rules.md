# OpenSpec Rules

Universal rules for OpenSpec work — apply in any project.

## Task Naming

* Prefix: every task starts with `FR`.
* Numbering: `FR N.M` — `N` group, `M` task within group.
* Title: a few words stating what the task does.
* Format: kebab-case, no spaces (`FR 1.1 Define ratio` → `fr-1.1-define-ratio`).
* File references live in the task body, never in the name.
* Branch name = task id + kebab-case title: `FR 1.1 Define ratio` → `fr-1.1-define-ratio`; fixed at task creation.

## Waves

* A wave = one `## N.` group; groups are ordered by dependency (group `N` depends only on `1…N−1`).
* A deliverable is not developed until the one it depends on is complete.
* Finish all tasks of the wave, mark `- [x]`, stop and report before the next wave.
* One subagent run = one task (FR). Never dispatch a whole wave in one run.
* Real invariants: one task = one executor run, completable in under 10 minutes, with a mechanical stop criterion.
* Task size: new/edited text.
  * Above 6000 chars — split (hard limit); a new-file task estimated above 5000 — split.
  * Below 2000 — merge with a related task of the same group, but only if the task is not independently verifiable. A coherent, verifiable task below 2000 stays whole. Trivial tasks (< 500) merge.
  * A single-task change is exempt from the lower bound entirely.
  * Characters are a hint; the invariants above are the law.
* Roles: strong model / human — PRD, specs, design, wave breakdown; local model — execution of one task only.

## Execution

* Pending work = unchecked `- [ ]` tasks in tasks.md.
* Next wave = the first `## N.` group containing unchecked tasks.
* Active changes = directories in `openspec/changes/` except `archive/`.
* One active change and no explicit instruction → work in it.
* Several active changes and no explicit instruction → ask the user, do not guess.

## Plan Self-Check

Before delivering tasks.md, the planner verifies:

* Every capability from the proposal is covered by at least one task.
* Every task fits the executor invariant: one run, ≤ 10 minutes per the calibration.
* No code task above the 4000-character ceiling; heavy verification split into its own task.
* Implementation language and stack taken from design.md Decisions.
* Every task body ends with a stop criterion and a `Maps to scenarios:` line.
