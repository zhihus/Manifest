# Tasks: add-structure-parser

## 1. Structure rules cleanup

- [ ] FR 1.1 Cleanup structure rules file

  Edit `workflow/file-structure-rules.ru.md`:
  1. Remove the double blank line before `## 3. Описание шапки
     документа` (lines 205-206) — leave exactly one blank line, as
     between all other sections.
  2. Fill section 6 per its item 6.1: under `### 6.1. Правильный`
     append a code fence (```` ``` ````) containing the entire current
     content of `workflow/naming-rules.ru.md`, then the closing fence.
  3. Re-check: `grep -n "^#\{2,4\} " workflow/file-structure-rules.ru.md`
     shows uninterrupted numbering 1-6; no line exceeds 100 characters
     (`awk 'length($0)>100' file` prints nothing); metadata lines 4-7
     still end with two spaces.

  Stop criterion: all three checks pass; the file still parses as
  before (sections 1-6 in order).
  Maps to scenarios: clean reference file.

## 2. Parser skeleton and line basics

- [ ] FR 2.1 Add parser skeleton with CLI and report

  Create `scripts/structure-parser.sh` with `#!/usr/bin/env bash`,
  `set -euo pipefail`, header comment modeled on manifest-init's
  `scripts/init.sh`. Implement functions: `parse_args` (exactly one
  file argument; no argument → usage line to stderr, exit 2;
  non-existent path → error naming the path, exit 2), `load_lines`
  (read file into arrays: original lines, lengths; strip trailing
  `\r` for checks, never modify the file), `report` (print buffered
  violations as `file:line: rule: description` sorted by line number;
  exit 0 if none, else 1), `main` (pipeline parse_args → load_lines →
  report). Script is executable (`chmod +x`).
  Stop criterion: `bash scripts/structure-parser.sh` exits 2 with
  usage; `bash scripts/structure-parser.sh missing.md` exits 2;
  `bash scripts/structure-parser.sh workflow/naming-rules.ru.md`
  exits 0 with empty report.
  Maps to scenarios: missing argument, non-existent file, clean
  reference file.

- [ ] FR 2.2 Add line length check

  In `scripts/structure-parser.sh` add `check_line_length`: for each
  loaded line with length >100 (after `\r` strip) buffer violation
  `file:line: line-length: line is N characters (limit 100)`; wire it
  into `main` before `report`.
  Stop criterion: on `workflow/naming-rules.ru.md` exit 0; on a temp
  fixture `temp/parser-fixture-long.md` containing one 101-character
  line, exit 1 and the report cites exactly that line number once.
  Maps to scenarios: long line, violation report format.

## 3. Classification-dependent checks

- [ ] FR 3.1 Add line classification and region check

  Add `classify_line`: assign each line one class — blank, heading
  (level = count of leading `#`), metadata (starts `> **`), code-fence
  open/close/content (track fence state across lines), label (exact
  `Правильно` or `Неправильно`), example (starts `✅` or `❌`), other
  text. Add `check_regions`: lines 1-10 must belong to the header
  region (title line 1, `# Метаданные` line 3, metadata 4-7,
  `# Описание` line 9, description from line 10); a numbered `##`
  section titled `Примеры` starts the footer region; deviation is a
  buffered violation citing rule 2.16.
  Stop criterion: `workflow/naming-rules.ru.md` and
  `workflow/commit-rules.ru.md` exit 0; a fixture with `# Описание`
  missing exits 1 citing the region rule.
  Maps to scenarios: clean reference file, negative fixture.

- [ ] FR 3.2 Add label and example checks

  Add `check_labels` (a label must be a plain text line, not a
  heading; any example line requires a preceding Правильно/Неправильно
  label in the same section) and `check_examples` (example lines start
  with `✅`/`❌`; each obeys the nearest preceding label). Wire both
  into `main`.
  Stop criterion: `workflow/naming-rules.ru.md` and
  `workflow/file-metadata-change-rules.ru.md` exit 0; a fixture with a
  `✅` line under `### X.Y. Неправильные` heading only exits 1 with
  both violations (label format, example without label).
  Maps to scenarios: label as heading, example without label.

- [ ] FR 3.3 Add logical line check

  Add `check_logical_lines`: a run of non-blank lines under a heading
  is one logical line until a blank line; a blank line inside
  metadata lines 4-7 and a heading continued on the next line are
  violations citing rule 2.4; a wrapped description paragraph
  (physical lines 10-11) is NOT a violation.
  Stop criterion: `workflow/commit-rules.ru.md` (wrapped description
  at lines 10-11) exits 0; a fixture with a blank line inside
  metadata exits 1 citing rule 2.4.
  Maps to scenarios: description paragraph, negative fixture.

## 4. Header and numbering checks

- [ ] FR 4.1 Add header and metadata value checks

  Add `check_header`: line 1 is a title up to 5 words / 35 chars;
  line 3 is `# Метаданные`; lines 4-7 are Status/Type/Version/Updated
  in order, each ending with two trailing spaces; line 9 is
  `# Описание`; line 10 is non-empty description. Add
  `check_metadata_values`: Status ∈ {draft, approved, archived};
  Version matches `X.Y.Z`; Updated matches ISO `YYYY-MM-DD`; Type is
  `document`. Wire into `main`.
  Stop criterion: all four `workflow/*.ru.md` rule files exit 0; a
  fixture with `> **Status: in-development**  ` and
  `> **Version: 1.0**  ` exits 1 citing both value rules with correct
  line numbers.
  Maps to scenarios: status outside the list, version not X.Y.Z,
  metadata line without hard break.

- [ ] FR 4.2 Add heading numbering and length checks

  Add `check_heading_numbering` (hierarchy N. → N.M. → N.M.K.; numbers
  continuous across body and footer; `#` headings only in header
  region; missing/duplicate numbers are violations) and
  `check_heading_length` (heading line >100 chars, or a heading whose
  rule text continues on the next line — violations). Wire into
  `main`.
  Stop criterion: `workflow/file-structure-rules.ru.md` and
  `workflow/manifest-workflow-rules.ru.md` exit 0 on numbering; a
  fixture with `## 1.` then `## 3.` exits 1 citing the gap at the
  `## 3.` line.
  Maps to scenarios: numbering gap, skipped sublevel, wrapped heading.

## 5. Heavy verification

- [ ] FR 5.1 Run reference and negative verification

  Create fixture `temp/parser-fixture-negative.md` seeded with five
  violations: 101-char line, `## 1.` then `## 3.` gap,
  `> **Status: in-development**  `, `### X.Y. Неправильные` as label,
  `✅` line without label. Run
  `bash scripts/structure-parser.sh <file>` on it and on the four
  reference files `workflow/naming-rules.ru.md`,
  `workflow/file-metadata-change-rules.ru.md`,
  `workflow/commit-rules.ru.md`,
  `workflow/file-structure-rules.ru.md`.
  Stop criterion: fixture → exit 1, each of the five violations
  reported exactly once with correct line numbers; each reference →
  exit 0 with empty report (structure file honors its section 1
  exceptions). Attach all five outputs to the task result.
  Maps to scenarios: negative fixture, clean reference file.
