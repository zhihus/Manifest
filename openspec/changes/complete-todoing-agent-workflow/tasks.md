# Tasks: complete-todoing-agent-workflow

## 1. Runbook

- [x] fr-1.1-document-todoing-only-lifecycle
  Add a complete standalone Todoing task lifecycle for the configuration where
  Todoing is enabled and OpenSpec is disabled. Cover discovery, duplicate avoidance,
  task granularity, user approval, dependencies, execution, review, completion,
  cancellation, and recovery in RU and EN runbooks.
  Stop: both language editions define the same lifecycle and do not require OpenSpec.

- [x] fr-1.2-document-compatible-api-build
  Pin the tested Todoing source baseline and state that public `main` lacks the
  extension operations required by the full workflow.
  Stop: the source commit used by Manifest acceptance CI is documented.

- [x] fr-1.3-correct-json-api-invocation
  Document the actual CLI form `todoing --json api` and remove the reversed form.
  Stop: RU/EN runbooks and bootstrap reference use the supported argument order.

## 2. Acceptance

- [x] fr-2.1-add-todoing-only-api-scenario
  Add a separate temporary project with no `openspec/` directory and exercise
  task creation, listing, dependency add/list/remove, approval baseline, lock,
  update, Review, final commit, completion, and release without OpenSpec operations.
  Stop: the acceptance test asserts the task is completed with no external
  references and no OpenSpec directory.

- [x] fr-2.2-add-runbook-regression-checks
  Extend the bilingual runbook test to check Todoing-only instructions, API command
  syntax, and the absence of OpenSpec archive commands from the Todoing-only section.
  Stop: static checks cover both language editions.

## 3. Environment verification

- [ ] fr-3.1-run-ci-acceptance
  Confirm the GitHub Actions run for this change passes against the pinned Todoing
  build. Do not mark this task complete based on source inspection alone.
  Stop: acceptance workflow reports success.

- [ ] fr-3.2-verify-role-access-boundary
  Verify whether the user's agent runtime prevents role agents from invoking the
  Todoing CLI directly. If it does not, report the limitation; do not claim that
  `actor_id` or workflow instructions provide technical authentication.
  Stop: runtime boundary is evidenced or explicitly reported as unenforced.
