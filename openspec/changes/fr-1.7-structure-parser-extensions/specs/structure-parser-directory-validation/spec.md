# Structure Parser Directory Validation

## Purpose

Define recursive Markdown validation while preserving the existing
single-file parser interface.

## Requirements

### Requirement: Explicit directory scope

The parser MUST accept an explicit directory argument in directory
mode and MUST NOT infer or scan the repository root implicitly.

#### Scenario: Directory mode

- **WHEN** the user runs `structure-parser.sh --dir <directory>`
- **THEN** the parser recursively discovers regular files ending in
  lowercase `.md` below that directory
- **AND** it does not follow symbolic links.

### Requirement: Complete traversal

The parser MUST validate every discovered Markdown file, even when
one or more earlier files contain violations.

#### Scenario: Multiple files with violations

- **WHEN** a directory contains both valid and invalid Markdown files
- **THEN** every discovered file is checked
- **AND** diagnostics identify the corresponding file and line.

### Requirement: Aggregate result

The parser MUST return 0 only when all discovered files pass, 1 when
at least one file has a validation violation, and 2 for invalid
arguments, a missing directory, or no matching Markdown files.

#### Scenario: Aggregate failure

- **WHEN** at least one file fails validation
- **THEN** the parser completes traversal and returns 1.

### Requirement: Single-file compatibility

The existing `structure-parser.sh <file.md>` invocation MUST retain
its behavior and exit-code contract.

#### Scenario: Existing invocation

- **WHEN** the user supplies one Markdown file without directory mode
- **THEN** only that file is validated using the existing checks.

### Requirement: Safe path handling

Directory traversal MUST safely handle spaces and shell-special
characters in paths and filenames.

#### Scenario: Path contains spaces

- **WHEN** the target directory or a Markdown filename contains spaces
- **THEN** the parser validates the file without splitting its path.
