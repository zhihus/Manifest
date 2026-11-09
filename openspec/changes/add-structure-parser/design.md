# Design

## Context

Manifest documents follow `workflow/file-structure-rules.ru.md`
(header with metadata, numbered body, examples footer, per-line
templates). Validation is manual today. The parser is a single bash
script, no build step, runs from source (see proposal.md — Why).
Reference files for verification: four RU rule files under `workflow/`.

## Goals / Non-Goals

**Goals:**

- Deterministic per-line validation with exact 1-based line numbers.
- Cross-platform by convention: Linux and Windows via Git Bash.
- Extension points for later: directory walk, hook, schedule.

**Non-Goals:**

- No repository-wide traversal in this change (MVP: one file per run).
- No auto-fixing; the parser only reports.
- No integration into `.manifest/hooks/pre-commit` yet.

## Decisions

- **Bash + POSIX tools only (awk/sed/grep).** Rationale: matches the
  existing manifest-init script (`scripts/init.sh` in the skills
  project: `#!/usr/bin/env bash`, `set -euo pipefail`); zero
  dependencies; runs where git runs. Alternative considered: Python
  (richer string handling) — rejected for now because the framework's
  executable convention is bash and model-run scripts should not need
  an interpreter install.
- **One file per run (MVP).** Directory walking is a separate later
  capability; keeping MVP single-file keeps every check independently
  testable and the change small.
- **Checks as independent functions over a shared line catalog.**
  `load_lines` builds an array (original line, length, normalized
  content); `classify_line` assigns one of: blank, heading, metadata,
  code-fence, label, example, other. Every `check_*` consumes the
  catalog, not the raw file — so checks never re-parse and stay
  unit-testable.
- **CRLF normalization at load time.** Windows working copies may hold
  `\r`; the parser strips it for checks and never rewrites the file.
  Trailing two-space hard-break detection runs after `\r` stripping.
- **Violations accumulate in a list, report prints once.** Each
  violation is buffered as `file:line: rule: description`; ordering by
  line number happens at print time. Exit code: 0 clean, 1 violations,
  2 usage error.
- **Unicode literals in patterns.** `✅`/`❌` and Russian labels are
  matched as literal bytes; Git Bash on Windows handles UTF-8 with
  `grep -P` unavailable — use awk with LC_ALL=C avoided, default
  locale, matching on fixed strings instead of regex classes.

## Risks / Trade-offs

- [bash string handling with UTF-8 emoji is locale-sensitive] →
  match on fixed strings and byte patterns; verify on Git Bash in
  verification task.
- [code fences contain arbitrary content that must not be checked] →
  classification tracks fence state; in-fence lines are exempt from
  text checks (length check still applies to their source lines only
  in non-rule contexts — resolved: in-fence lines are fully exempt).
- [structure rules may evolve and break the parser] → the rules file
  itself is a parser input contract; rules changes go through the
  OpenSpec process, keeping parser and rules in sync.

## Migration Plan

Additive: new script, no existing behavior changes except the
structure-rules cleanup (removing a cosmetic blank line, filling the
planned section 6). Rollback: delete `scripts/structure-parser.sh`.

## Open Questions

None — MVP scope, language, and verification fixtures are agreed in
`docs/plans/structure-parser-plan.en.md`.
