# Spec Delta

## Purpose

The verify-script capability mechanically keeps the structure parser
in sync with the structure rules source file, runs the parser's
regression tests, and is triggered both manually and by a pre-commit
hook, so divergence cannot be committed unnoticed.

## ADDED Requirements

### Requirement: CLI and exit codes

verify.sh MUST take no arguments, MUST exit 0 when all checks pass
and exit 1 on any failure, printing each failure as a bilingual
`verify.sh: FAIL: <message>` line and success as `verify.sh: OK`.

#### Scenario: clean tree

- **WHEN** verify.sh runs with no changes to the rules file or the
  parser since HEAD
- **THEN** it exits 0 and prints `verify.sh: OK`

#### Scenario: missing parser

- **WHEN** `scripts/structure-parser.sh` does not exist
- **THEN** verify.sh exits 1 with a FAIL line naming the missing file

### Requirement: rules and parser change together

When the rules file is changed against HEAD but the parser is not,
verify.sh MUST fail with a bilingual message instructing to update
the parser and commit both files together.

#### Scenario: rules changed without parser

- **WHEN** `workflow/file-structure-rules.ru.md` differs from HEAD
  and `scripts/structure-parser.sh` does not
- **THEN** verify.sh exits 1 with the "update the parser" message

#### Scenario: rules and parser changed together

- **WHEN** both files differ from HEAD
- **THEN** verify.sh runs the parser tests and reports their result

### Requirement: parser tests

When the parser is changed (alone or with the rules), verify.sh MUST
run two test groups: references (parser on every
`workflow/*.ru.md` and `workflow/*.en.md`, expected exit 0) and a
negative fixture generated on the fly in a temporary directory
(five seeded violations, expected parser exit 1). Any deviation is a
FAIL with details.

#### Scenario: parser regression on references

- **WHEN** a modified parser reports violations on a reference file
  that must be clean
- **THEN** verify.sh exits 1 and lists that file's violations

#### Scenario: parser misses seeded violations

- **WHEN** a modified parser exits 0 on the negative fixture
- **THEN** verify.sh exits 1 with a FAIL naming the fixture check

### Requirement: pre-commit trigger

The hook `scripts/hooks/pre-commit` MUST be a thin wrapper that runs
`scripts/verify.sh` from the repo root and returns its exit code,
so a commit violating the sync rules is blocked with the verify.sh
output visible in the terminal.

#### Scenario: blocked commit

- **WHEN** a commit includes only the rules file change
- **THEN** the pre-commit hook fails the commit and the "update the
  parser" message is visible in the terminal

#### Scenario: passing commit

- **WHEN** a commit includes rules plus parser changes and all
  checks pass
- **THEN** the commit completes
