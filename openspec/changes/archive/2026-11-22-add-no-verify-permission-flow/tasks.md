# Tasks

## 1. Instruction block in verify.sh

- [x] FR 1.1 Replace the hard-fail message in the `rules` branch of
  `main()` in `scripts/verify.sh` with an action-required instruction
  block that: names both files (`workflow/file-structure-rules.ru.md`,
  `scripts/structure-parser.sh`); lists path (a) update the parser to
  match the rules and commit both files together; lists path (b) if
  the rules change requires no parser change, ask the user for
  permission to commit with `--no-verify` via the harness's standard
  permission-request mechanism; states explicitly that the hook can
  only print text and the permission dialog is created by the agent.
  Keep the non-zero exit. Stop criterion: `bash scripts/verify.sh`
  with only the rules file changed (against HEAD) prints both paths
  and the flag `--no-verify`, and exits 1.
  Maps to scenarios: Rules changed, parser untouched; Agent cannot
  skip the user.

## 2. Verification

- [x] FR 2.1 Verified 2026-11-10: (1) nothing changed → `verify.sh: OK`, exit 0; (2) rules changed, parser untouched → instruction block with both paths and `--no-verify`, exit 1; (3) both changed, parser passes references and fixture → `verify.sh: OK`, exit 0. Original task: Verify all three gate paths end-to-end and commit:
  (1) rules changed, parser untouched → instruction block, exit 1;
  (2) rules and parser changed together, parser passes references and
  fixture → `verify.sh: OK`, exit 0; (3) nothing changed → `verify.sh:
  OK`, exit 0. Record results in the task comment. Stop criterion: the
  three runs above are observed and their outputs pasted into the
  completed task entry.
  Maps to scenarios: Rules changed, parser untouched; Rules and parser
  changed together; Agent follows remediation path (b).
