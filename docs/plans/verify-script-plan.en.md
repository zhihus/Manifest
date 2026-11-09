# Plan: verify script and rules-sync pre-commit hook

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-09**  

# Description
Plan for the verify script that keeps the structure parser in sync
with the structure rules source file.

## 1. Model

### 1.1. Derivative rule

The structure rules file (`workflow/file-structure-rules.ru.md`) is
the source of truth. The parser (`scripts/structure-parser.sh`) is
its derivative: the parser changes only when the source changes.
Exception — a parser bug fix, which is allowed but must prove
conformance to the source by tests.

### 1.2. Baseline

Comparison point is HEAD: the version of the rules file before the
change. Per commit rules, rules and parser change in one commit, so
HEAD is always a consistent state.

## 2. verify script

### 2.1. Location and style

`scripts/verify.sh` holds all the check logic (bash, `set -euo
pipefail`, modeled on `scripts/structure-parser.sh`, commented
sections).

### 2.2. Four branches

Based on `git diff HEAD --name-only` over the rules file and the
parser:

1. Nothing changed → OK, exit 0.
2. Only the parser changed (bug fix) → run the parser tests (see 2.3).
3. Only the rules changed → FAIL: "the structure rules changed but
   `scripts/structure-parser.sh` was not updated — update the parser
   and commit both files together" (bilingual message).
4. Rules and parser changed → run the parser tests (see 2.3).

### 2.3. Parser tests

- References (the "over-reporting" test): run the parser on all
  `workflow/*.ru.md` and `workflow/*.en.md`; expect exit 0. Any
  failure — FAIL with the parser's violation list.
- Negative fixture (the "under-reporting" test): a file with five
  violations (long line, numbering gap, out-of-list status, label as
  heading, example without label) generated on the fly in a temp dir
  (`mktemp -d`, removed on exit); expect parser exit 1. Otherwise
  FAIL.

### 2.4. Existence check

The rules file and the parser must exist at their paths; absence is
a FAIL.

### 2.5. Report

`verify.sh: OK` → exit 0; `verify.sh: FAIL: <message>` lines
(bilingual, as in structure-parser.sh) → exit 1.

## 3. Pre-commit hook

### 3.1. Wrapper

`scripts/hooks/pre-commit` is a ~5-line wrapper with a comment: it
resolves the repo root (`git rev-parse --show-toplevel`), runs
`bash "$ROOT/scripts/verify.sh"`, and returns its exit code. Both
files are versioned in the repository.

### 3.2. Activation

Local configuration (not committed): `git config core.hooksPath
scripts/hooks`.

## 4. Work order

### 4.1. Verify script

Write `scripts/verify.sh` (checks 2.2–2.5).

### 4.2. Manual check

Clean tree → OK; temporarily change only the rules file → FAIL with
the parser message; revert.

### 4.3. Hook

Write `scripts/hooks/pre-commit`, chmod +x both scripts, activate
`core.hooksPath`.

### 4.4. Hook check

A commit changing only the rules file is blocked; a commit changing
rules plus parser passes.

### 4.5. Commits

`docs(openspec): propose add-verify-script change` → `feat(verify):
add verify script and pre-commit rules-sync hook`.

## 5. End-to-end verification

- `bash scripts/verify.sh` on a clean tree → exit 0.
- A commit changing only the rules file → blocked by the hook with
  the bilingual message (checked on a temporary edit, then reverted).
- A commit with rules plus parser changes → passes, parser tests
  green.
- A deliberately broken parser → references FAIL, commit blocked.
