# Tasks: implement-todoing-manifest-workflow

## Wave 1 — normative runbook

- [x] FR 1.1 write-russian-runbook

Extend `workflow/README.ru.md` with safe bootstrap, Project ID/config validation, dependency readiness, approved `ready → in_progress` transition, lock custody, Review, exact OpenSpec archive commands, completion, cancellation, and recovery. Use only operations present in Todoing API v1 and OpenSpec CLI 1.16.0. Preserve approval and no-overwrite invariants.
Stop criterion: every requirement in `manifest-todoing-runbook/spec.md` is covered by the Russian runbook; no unsupported Todoing operation is named.
Maps to scenarios: New project bootstrap; Existing store without identity; Unapproved task; Block work on an incomplete prerequisite; Start approved work; Role agent execution; Review requests changes; Successful completion; Cancellation; Lost lock-release response.

- [x] FR 1.2 write-english-runbook

Extend `workflow/README.en.md` with a semantically equivalent English runbook. Keep operation names, dependency gating, status transitions, archive flags, ordering, lease duration, error behavior, and approval gates identical to the Russian version.
Stop criterion: both language editions describe the same operations and safety invariants.
Maps to scenarios: all scenarios in manifest-todoing-runbook.

## Wave 2 — mechanical verification

- [x] FR 2.1 add-runbook-regression-test

Create regression tests that check both runbook editions for mandatory API operations, dependency gating, status transitions, explicit archive flags, user approval gates, 720-second lease, token custody, recovery reconciliation, and completion/cancellation ordering. Parse both TOML examples, require them to be identical, and validate the approved status graph and lock settings. Include negative checks for unsafe automatic initialization and lock release without ownership confirmation.
Stop criterion: the test exits 0 for the completed runbook and fails when any required invariant is removed from a fixture copy.
Maps to scenarios: all scenarios in manifest-todoing-runbook.

- [x] FR 2.2 wire-ci-and-validate

Wire the regression test into the Manifest CI workflow and run OpenSpec validation. Keep CI limited to read-only checks.
Stop criterion: GitHub Actions reports passing OpenSpec validation and runbook regression jobs on this feature branch; no local-only result is reported as CI evidence.
Maps to scenarios: all scenarios in manifest-todoing-runbook.

- [x] FR 2.3 verify-snapshot-restore-runbook-contract

Document `store.snapshot`, `store.snapshot.verify`, and
`store.snapshot.restore` in both runbook editions. State the active-lock
guard, same-Project-ID/schema requirement, retained pre-restore safety
snapshot, and the boundary that restore affects Todoing SQLite only. Require
explicit user approval and the retained expected SHA-256 before destructive
restore. Extend the regression test to check these requirements and
recovery-section ordering.
Stop criterion: bilingual runbook and regression test cover the snapshot
restore safety contract.
