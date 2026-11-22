# Proposal

## Why

Document structure per `workflow/file-structure-rules.ru.md` is checked
by humans or models "by eye". A mechanical validator is needed so the
framework can gate documents automatically (hook, schedule, manual run)
and models get deterministic feedback with exact line numbers.

## What Changes

- Add a new bash script `scripts/structure-parser.sh` (cross-platform:
  Linux and Windows via Git Bash), modeled on manifest-init's
  `scripts/init.sh` (`#!/usr/bin/env bash`, `set -euo pipefail`).
- MVP scope: the script takes ONE Markdown file as an argument and
  validates it against the structure rules; exit 0 clean, exit 1
  violations, exit 2 usage error.
- Cleanup prerequisite in `workflow/file-structure-rules.ru.md`:
  remove the double blank line before section 3; fill section 6
  "Examples" by inserting `workflow/naming-rules.ru.md` whole in a code
  fence per its own item 6.1 (this file becomes the parser's
  reference: a correct file must exit 0).
- 14 independent shell functions: arg parsing, line loading (CRLF-safe),
  line length, line classification, regions, header templates,
  metadata values, heading numbering, heading length, labels, examples,
  logical lines, report, main pipeline.
- Out of scope (later changes): directory walk, pre-commit hook
  integration, scheduled runs.

## Capabilities

### New Capabilities

- `structure-parser`: mechanical validation of Manifest Markdown
  documents against the structure rules (header layout, metadata
  values, numbering, regions, labels, examples, logical lines) with a
  per-line violation report.

### Modified Capabilities

## Impact

- New file: `scripts/structure-parser.sh` (no build step, runs from
  source; awk/sed/grep only — no new dependencies).
- Edited file: `workflow/file-structure-rules.ru.md` (cleanup step 0).
- Verification uses existing reference files under `workflow/` and a
  negative-test fixture in `temp/` (gitignored, not committed).
