# Agent Rules — Accumulator Draft

> Accumulator draft — material for future agent file releases; not
> shipped in the distribution. Assembled from `docs/templates/`.

## 1. Project (from `agents.template.md`)

* Name: project name placeholder.
* Purpose: project purpose; entry point if established.
* Context: free-form project context for the agent.

## 2. Files and access (from `agents.template.md`)

* Read `.llmignore` first; access ignored paths only with explicit
  permission.
* Do not change files or architecture outside the current task without
  user request.
* Read files referenced in context only at the relevant stage.
* temp/ folder: see `temp-folder-rules`.

## 3. Base rules (from `agents.template.md`)

* Current task = the single task currently requested by the user.
* Before code → write a test reproducing the issue or verifying
  expected behavior.
* No test, no code.
* No implementation TODO list without user approval.
* Copy-paste output (prompts, commands, code, config) → fenced code
  block, not plain text.

## 4. Code (from `code-rules.template.md`)

Purpose: simple, correct, explicit, maintainable code.

* Simplicity — simplest correct solution; no speculative abstractions.
* Explicitness — dependencies, state, flow, side effects, ownership,
  error handling explicit; no hidden global state.
* Responsibility + Locality — one clear responsibility per component;
  related logic and state stay local.
* Readability — clear domain names; project/language conventions.
* Low Coupling — minimise dependencies; explicit over DI machinery.
* Established Patterns — follow existing patterns and authoritative
  sources first.
* Change Discipline — smallest change that solves the problem; no
  unrelated rewrites; fix root causes.
* Error Handling — never silently swallow errors; handle, propagate or
  explicitly suppress with context; validate inputs.
* Verification — verify through direct, deterministic mechanisms;
  tests validate outcomes; passing tests are evidence, not proof.
* Maintainability — optimise for long-term evolution.

Exceptions: guidelines, not mechanical constraints; deviate when
required by correctness, security, performance, simplicity or
established architecture.

## 5. Tests (from `code-test-rules.template.md`)

* TDD — test before implementation; no test, no code.
* Isolation — one test verifies one behaviour; isolated, repeatable.
* Priority — critical paths first: happy path, edge cases, errors.
* Coverage — all public APIs and critical logic; ≥80% for core modules.
* Regression — reproduce a bug with a regression test before fixing.
* Verification — tests validate outcomes, not merely execute.
* Pre-commit — all required local tests pass before commit.

Structure: unit / integration / end-to-end; alongside source or in
`tests/`. Naming: describe behaviour, not implementation.

## 6. Logging (from `code-log-rules.template.md`)

Record: timestamp, level, component, event, message, optional context.
Format: `[YYYY-MM-DD HH:MM:SS] [LEVEL] [component] message`.

* Log failures, important transitions, recovery, degradation,
  lifecycle boundaries.
* `info` / `warn` / `error` semantics per template.
* Enough context to identify the affected operation/resource.
* No duplication across layers unless the higher layer adds
  information.
* Never log credentials, secrets, tokens; avoid sensitive data.
* No per-poll/frame/callback/tick/retry logging; no repeated unchanged
  state.
* Logging must not materially affect behaviour.

## 7. Git and commits (from `commit-rules.template.md`)

* Format `<type>(<scope>): <subject>`; types: feat, fix, docs, style,
  refactor, perf, test, build, ci, chore, revert.
* Subject: English, imperative, lowercase, target ≤50 chars.
* Body: why, what changes, non-obvious decisions; not the diff.
* Footers: `Refs:`, `Closes:`, `BREAKING CHANGE:`; breaking = `!` +
  footer.
* One logical change per commit; local checks before committing; no
  history rewriting without permission; messages in English.
* Review & merge: task branch from `develop`; reviewer verifies the
  wave diff; merge after pass; conflicts escalate, never self-resolve.

## 8. Versioning (from `versioning.template.md`)

* `X.Y.Z` (SemVer); optional `X.Y.Z-{alpha|beta|rc}.N`.
* `VERSION` file is the single source of truth; one version per line.
* Released versions cannot be decreased or reused.
* Bump: breaking → major, feature → minor, fix → patch, mixed →
  highest; reset lower components.
* Pre-release: same stage → `N+1`; new stage → `N=1`; progression
  alpha → beta → rc, skippable.

## 9. Releases (from `code-releases.template.md`)

* Branches: `develop` — all development; `master` — release-ready.
* Release: build, verify, merge `develop` → `master`, verify, tag
  `vX.Y.Z`, artifact.
* One release = one tag = one version; tags only on `master`, tags
  immutable; failed verification → no merge, no tag; no rebase,
  force-push, direct commits to `master`.

## 10. OpenSpec tasks (from `open-spec-rules.template.md`)

* Every task: prefix `FR`; numbering `FR N.M` (N = group/wave, M =
  task).
* Title: a few words, kebab-case, no spaces, no file references.
* Wave = one `## N.` group; groups ordered by dependency; finish a
  wave, mark `- [x]`, stop and report before the next.
* One executor run = one task.

## 11. Navigation (from `llm.template.txt`)

* Project name and purpose; entry point.
* Directory map; build method.
* Rules index: workflow, code, tests, logging, commits, versioning,
  releases.
