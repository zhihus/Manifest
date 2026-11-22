# Design: extend-structure-parser

## Context

`scripts/structure-parser.sh` currently accepts one file and exits
after validating it. Roadmap item 1.7 calls for directory traversal
and scheduled runs.

## Goals / Non-Goals

**Goals:**
- Preserve the existing single-file command and exit-code contract.
- Add recursive validation of Markdown files in an explicit directory.
- Continue through all discovered files and aggregate failures.
- Support paths containing spaces and other shell-special characters.
- Use the same Bash baseline as the existing parser and rely only on standard utilities already required by the project.
- Make periodic execution possible through external schedulers.

**Non-Goals:**
- Change document structure rules or validation semantics.
- Scan the entire repository implicitly.
- Follow symbolic links during directory traversal.
- Install, configure, or manage cron, Windows Task Scheduler, or
  another scheduler.
- Add automatic pre-commit integration.
- Change connected-project distribution.

## Decisions

- D1. Keep `structure-parser.sh <file.md>` unchanged.
- D2. Add `structure-parser.sh --dir <directory>`. The directory is
  required explicitly; the parser does not guess a project root.
- D3. Recursively discover regular files whose names end in lowercase
  `.md`. Do not follow symbolic links. Process paths safely, including
  spaces, by using NUL-delimited traversal.
- D4. Run the existing per-file validation pipeline for every file.
  A violation in one file must not prevent checks of later files.
- D5. Print each file's existing diagnostics and return 1 if any file
  has violations. Return 0 only when every discovered file passes.
  Invalid arguments, a missing directory, or a directory with no
  matching Markdown files return 2 with an actionable message.
- D6. Keep the current single-file exit codes: 0 clean, 1 violations,
  2 usage/input error.
- D7. Scheduled execution is documentation-only. Users configure
  their OS scheduler to run the one-shot `--dir` command. The parser
  must not daemonize, sleep, or mutate scheduler configuration.
- D8. Add a regression script covering single-file compatibility,
  nested discovery, spaces in paths, aggregate failures, empty
  directories, and invalid arguments.

## Risks / Trade-offs

A directory may contain Markdown files that do not follow the
Manifest structure rules. The caller controls scope by choosing the
directory; the parser deliberately does not silently exclude files
based on naming conventions.

## Unresolved Questions

None.
