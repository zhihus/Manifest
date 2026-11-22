# Tasks: extend-structure-parser

## 1. Directory validation

- [ ] FR 1.7 directory-mode
  Add `--dir <directory>` while preserving the single-file interface.
  Recursively discover regular `.md` files, validate all files, and
  aggregate the exit status. Add focused regression tests.
  Stop criterion: all directory-mode scenarios pass; single-file
  behavior remains unchanged; `bash -n` passes for implementation
  and test script.
  Maps to scenarios: Single-file compatibility; Nested Markdown
  discovery; Paths with spaces; All files checked after a violation;
  Aggregate failure status; Empty directory; Invalid directory.

## 2. Scheduled execution documentation

- [ ] FR 1.8 scheduled-run-guide
  Document one-shot scheduled invocation for cron and Windows Task
  Scheduler. State prerequisites and show how to capture exit status
  and logs. Do not install or configure a scheduler.
  Stop criterion: examples invoke the documented `--dir` interface
  and do not require a resident process or Manifest-specific daemon.
  Maps to scenarios: Periodic execution by an external scheduler;
  Scheduled run reports validation failure.
