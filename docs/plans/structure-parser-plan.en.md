# Plan: Markdown structure parser (MVP)

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-09**  

# Description
Plan for a script that validates documents against Manifest structure
rules; one plan item equals one script function.

## 1. Preliminary check of the structure rules file

### 1.1. Result

`workflow/file-structure-rules.ru.md` has no errors: declared line
numbers (1, 3-7, 9-10) match the actual file; metadata lines 4-7 end
with a hard break (two trailing spaces); heading numbering is
hierarchical and continuous; no lines exceed 100 characters. Two
fixable issues found — handled in section 2 of this plan.

## 2. Step 0 - cleanup of the structure rules file

### 2.1. Double blank line

Remove the double blank line before "## 3. Описание шапки документа"
(lines 205-206) — leave one, as between all other sections.

### 2.2. Filling section 6 "Examples"

Fill section 6 completely per its own text (6.1): insert the entire
file `workflow/naming-rules.ru.md` wrapped in a code fence under
"### 6.1. Правильный". This is the parser's reference: a correct file
by definition exits 0.

### 2.3. Re-check

After the edits, re-check the structure file: line numbers, metadata
hard breaks, numbering, line lengths.

## 3. Solution format

### 3.1. Language

A bash script, modeled on manifest-init's `scripts/init.sh`
(`C:\WorkProjects\skills\manifest-init\scripts\init.sh`):
`#!/usr/bin/env bash`, `set -euo pipefail`. Works on Linux and Windows
(Git Bash). No external dependencies — awk/sed/grep only.

### 3.2. MVP

The script takes one file as an argument and validates it. Extensions
(directory walk, hook, schedule) are later iterations; the plan marks
extension points.

### 3.3. Location

Script: `scripts/structure-parser.sh` in the Manifest root.

## 4. Functions (one plan item = one function)

Each function is a separate shell function, tested independently.

### 4.1. `parse_args`

Argument parsing: path to the file to validate; no argument — usage
and exit 2 (modeled on init.sh).

### 4.2. `load_lines`

Read the file into an array of lines keeping the original and the
length of each line (CRLF handling: normalize `\r` for checks, do not
modify the file).

### 4.3. `check_line_length`

100-character limit per line (structure rule 2.2).

### 4.4. `classify_line`

Line classification: blank / heading (level by number of `#`) /
metadata (`> **`) / code-fence line / label "Правильно"/"Неправильно" /
example line (`✅`/`❌`) / other text. Basis for all later checks.

### 4.5. `check_regions`

Region layout: lines 1-10 → header, numbered `##` sections → body,
"Examples" section → footer; deviation from the scheme is a violation
(2.16).

### 4.6. `check_header`

Header per templates 3.1-3.8: line 1 — title (up to 5 words /
35 chars), line 3 — `# Метаданные`, lines 4-7 —
Status/Type/Version/Updated in order with two trailing spaces, line 9
— `# Описание`, line 10 — description text.

### 4.7. `check_metadata_values`

Metadata values: Status ∈ {draft, approved, archived}, Type = document,
Version = X.Y.Z, Updated = ISO YYYY-MM-DD (3.3-3.6).

### 4.8. `check_heading_numbering`

Numbering (2.3): hierarchy 1. → 1.1. → 1.1.1., continuous across the
footer, `#` only in the header; missing or duplicate numbers are
violations.

### 4.9. `check_heading_length`

Heading ≤100 characters, one physical line; a rule in a heading (4.1)
does not wrap.

### 4.10. `check_labels`

Labels "Правильно"/"Неправильно" are text, not headings; required when
examples are present (5.3-5.4).

### 4.11. `check_examples`

Example lines start with `✅`/`❌` and obey the nearest preceding label
(5.5).

### 4.12. `check_logical_lines`

Multi-line logical lines (2.4): description (3.8) and text under a
heading (4.2) — one paragraph until a blank line; headings and
metadata do not wrap.

### 4.13. `report`

Violation summary: `file:line: rule: description`; exit 0 — clean,
exit 1 — violations, exit 2 — usage error.

### 4.14. `main`

Pipeline: parse_args → load_lines → classification → all check_* →
report.

## 5. Work order

### 5.1. Cleanup

Complete section 2 (double blank line, section 6), re-check.

### 5.2. Plan

Store this plan in `docs/plans/`, review, compress
(compress-context).

### 5.3. Implementation

Implement `scripts/structure-parser.sh` (functions 4.1-4.14)
iteratively; commit after each working group of functions (per the
task-size calibration).

### 5.4. Verification

- References: `workflow/naming-rules.ru.md`,
  `workflow/file-metadata-change-rules.ru.md`,
  `workflow/commit-rules.ru.md`, `workflow/file-structure-rules.ru.md`
  — expect exit 0 (for the structure file, honoring its section 1
  exceptions).
- Negative test: a temp file in `temp/` with pre-seeded violations
  (long line, numbering gap, out-of-list status, label as heading,
  example without label) — expect exit 1 and exact line numbers in the
  report.
- The script output on all four reference files is attached to the
  task result.

## 6. Later iterations

Not part of the MVP, extension points: directory walk, integration
into `.manifest/hooks/pre-commit`, scheduled runs.
