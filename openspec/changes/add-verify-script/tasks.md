# Tasks: add-verify-script

## 1. Verify script and hook

- [x] FR 1.1 Add verify script with sync checks

  Create `scripts/verify.sh` (`#!/usr/bin/env bash`, `set -euo
  pipefail`, commented sections, modeled on
  `scripts/structure-parser.sh`). Implement, in order:
  1. existence check: `workflow/file-structure-rules.ru.md` and
     `scripts/structure-parser.sh` exist, else bilingual FAIL;
  2. changed-set analysis: `git diff HEAD --name-only --` over the
     two files; four branches (nothing → OK exit 0; only parser →
     parser tests; only rules → bilingual FAIL "update the parser and
     commit both files together"; rules+parser → parser tests);
  3. parser tests: references `workflow/*.ru.md` + `workflow/*.en.md`
     expected exit 0 (collect violations on failure); negative
     fixture generated in `mktemp -d` (five violations: 101-char
     line, `## 1.` then `## 3.` gap, `> **Status: in-development**  `,
     `### X.Y. Неправильные` label heading, `✅` line without label)
     expected parser exit 1, temp dir removed on exit;
  4. report: `verify.sh: OK` → exit 0, `verify.sh: FAIL: <message>`
     lines (bilingual) → exit 1.
  Stop criterion: `bash scripts/verify.sh` on the clean tree exits 0
  with `verify.sh: OK`; a temporary rules-only edit makes it exit 1
  with the "update the parser" message; revert the edit.
  Maps to scenarios: clean tree, missing parser, rules changed
  without parser, rules and parser changed together.

- [x] FR 1.2 Add pre-commit hook and activate it

  Create `scripts/hooks/pre-commit` (~5 lines with a comment: resolve
  root via `git rev-parse --show-toplevel`, run
  `bash "$ROOT/scripts/verify.sh"`, exit with its code); `chmod +x`
  both scripts; run `git config core.hooksPath scripts/hooks`.
  Stop criterion: `bash scripts/hooks/pre-commit` on the clean tree
  exits 0; `git config core.hooksPath` prints `scripts/hooks`.
  Maps to scenarios: blocked commit, passing commit.

- [ ] FR 1.3 Verify hook end-to-end

  Mechanical verification, one run:
  1. `git commit` attempt with a temporary rules-only edit staged →
     blocked, "update the parser" message visible; revert the edit.
  2. Commit of the OpenSpec artifacts plus scripts (rules + parser
     untouched) → passes.
  3. Negative fixture check: verify.sh FAILs if the parser is
     artificially broken (temporarily change the 100 limit to 10 in
     a copy — run verify.sh against a sandbox copy, not the real
     parser file) and passes with the real parser.
  Stop criterion: blocked commit observed, passing commit observed,
  both fixture directions observed.
  Maps to scenarios: blocked commit, passing commit, parser
  regression on references, parser misses seeded violations.
