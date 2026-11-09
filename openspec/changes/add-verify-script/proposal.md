# Proposal

## Why

The structure parser (`scripts/structure-parser.sh`) is a derivative
of the structure rules source (`workflow/file-structure-rules.ru.md`).
When the rules file changes, the model or human may forget to update
the parser, and the two silently diverge. A mechanical guard is
needed because memory cannot be relied upon.

## What Changes

- Add a root-level `scripts/verify.sh` (bash, `set -euo pipefail`)
  with the whole sync-check logic: existence of rules and parser,
  changed-since-HEAD analysis over the two files, parser test runs
  (references + on-the-fly negative fixture).
- Add `scripts/hooks/pre-commit` — a thin ~5-line wrapper that runs
  `verify.sh` and passes its exit code on; all logic lives in
  `verify.sh`.
- Activate locally via `git config core.hooksPath scripts/hooks`
  (not committed).
- Branch behavior: nothing changed → OK; only parser changed (bug
  fix, allowed) → parser tests; only rules changed → FAIL "update
  the parser and commit both together"; rules + parser → parser
  tests.
- Out of scope: delivery of verify.sh/parsser into connected
  projects (manifest-init `dist/`) — a separate change.

## Capabilities

### New Capabilities

- `verify-script`: root verification script that keeps the structure
  parser in sync with the structure rules source and reports results
  as bilingual OK/FAIL lines; plus its pre-commit trigger.

### Modified Capabilities

## Impact

- New files: `scripts/verify.sh`, `scripts/hooks/pre-commit`.
- Local config: `core.hooksPath` in the Manifest repository.
- Uses the existing parser and reference files; no parser changes.
