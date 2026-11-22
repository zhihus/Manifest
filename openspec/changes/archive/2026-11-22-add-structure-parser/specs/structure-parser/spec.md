# Spec Delta

## Purpose

The structure-parser capability mechanically validates a Manifest
Markdown document against `workflow/file-structure-rules.ru.md` and
reports violations with exact line numbers, so structure compliance
becomes checkable by scripts, hooks, and schedules.

## ADDED Requirements

### Requirement: CLI invocation and exit codes

The parser MUST accept exactly one Markdown file path as its first
argument and MUST exit 0 when the file passes all checks, exit 1 when
violations are found, and exit 2 on usage errors (missing argument,
non-existent file).

#### Scenario: clean reference file

- **WHEN** the parser runs with a fully compliant document (for
  example `workflow/naming-rules.ru.md`) as the argument
- **THEN** the process exits with code 0 and prints no violations

#### Scenario: missing argument

- **WHEN** the parser runs with no arguments
- **THEN** the process exits with code 2 and prints a usage line

#### Scenario: non-existent file

- **WHEN** the parser runs with a path that does not exist
- **THEN** the process exits with code 2 and prints an error naming
  the path

### Requirement: line length limit

The parser MUST report every line longer than 100 characters, with its
1-based line number.

#### Scenario: long line

- **WHEN** the document contains a line of 101 characters
- **THEN** the report contains an entry for that line number citing
  the length limit rule

### Requirement: header and metadata validation

The parser MUST validate the document header: line 1 is a title (up to
5 words / 35 characters), line 3 is `# Метаданные`, lines 4-7 are
Status/Type/Version/Updated in that order, each ending with two
trailing spaces, line 9 is `# Описание`, line 10 is non-empty
description text. Status MUST be one of draft, approved, archived;
Version MUST match X.Y.Z; Updated MUST match ISO YYYY-MM-DD.

#### Scenario: status outside the list

- **WHEN** line 4 contains `> **Status: in-development**` followed by
  two spaces
- **THEN** the report cites the status value rule at line 4

#### Scenario: metadata line without hard break

- **WHEN** a metadata line 4-7 lacks the two trailing spaces
- **THEN** the report cites the metadata template rule at that line

#### Scenario: version not X.Y.Z

- **WHEN** line 6 contains `> **Version: 1.0**  `
- **THEN** the report cites the version format rule at line 6

### Requirement: heading numbering

The parser MUST validate heading numbering: hierarchy N. → N.M. →
N.M.K., continuous numbering across body and footer, level-1 headings
only in the header region; missing or duplicate numbers MUST be
reported.

#### Scenario: numbering gap

- **WHEN** body headings go `## 1.` then `## 3.`
- **THEN** the report cites the numbering rule at the `## 3.` line

#### Scenario: skipped sublevel

- **WHEN** a `### 1.3.` heading follows `## 1.` directly after a
  `### 1.1.`
- **THEN** the report cites the numbering rule at the offending line

### Requirement: heading format

The parser MUST report a heading longer than 100 characters or a
heading whose rule text wraps onto the next physical line.

#### Scenario: wrapped heading

- **WHEN** a heading line is followed by a continuation line that is
  not blank, not a heading, and not allowed body text
- **THEN** the report cites the heading format rule at the heading line

### Requirement: labels and example lines

In the examples region, the parser MUST require that example lines
start with `✅` or `❌`, that each example line follows the nearest
preceding label (Правильно/Неправильно), and that a label is present
before any example lines. Labels MUST be plain text lines, not
headings.

#### Scenario: example without label

- **WHEN** a `✅` line appears with no preceding
  Правильно/Неправильно label after the last heading
- **THEN** the report cites the label rule at the example line

#### Scenario: label as heading

- **WHEN** a line `### X.Y. Неправильные` acts as the only marker
  before example lines
- **THEN** the report cites the label format rule

### Requirement: logical lines

The parser MUST treat a block of non-blank lines under a heading as one
logical line until a blank line, and MUST report blank lines inside
metadata lines 4-7 and any heading wrapped onto a following line.

#### Scenario: description paragraph

- **WHEN** the description text spans physical lines 10-11 with no
  blank line between them
- **THEN** the parser treats lines 10-11 as one logical line and
  reports no violation for the wrap

### Requirement: violation report format

The parser MUST print each violation as `file:line: rule: description`
in ascending line order, and MUST report every seeded violation exactly
once.

#### Scenario: negative fixture

- **WHEN** the parser runs on a fixture with five pre-seeded violations
  (long line, numbering gap, out-of-list status, label as heading,
  example without label)
- **THEN** the process exits 1 and the report contains each violation
  exactly once, with correct line numbers
