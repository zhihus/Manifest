# Verification: implement-todoing-manifest-workflow

## Scope

Independent review of the bilingual Todoing runbook, its OpenSpec delta, the
regression test, and CI wiring. No runtime orchestrator or persistent external
Todoing store is implemented by this change; the runbook is the normative
consumer procedure.

## Review Results

- Bootstrap preserves Project ID, store, legacy data, and existing configuration; ambiguous or mismatched state is a hard stop.
- Backlog approval remains user-controlled. Dependency readiness is checked before lock acquisition and dispatch.
- The Orchestrator alone calls Todoing and retains lock tokens. Role agents never receive tokens.
- The approved task is moved from `ready` to `in_progress` after lock acquisition and before dispatch.
- Review records are bound to immutable task versions; `changes_requested` increments `revision_count` once and `approved` maps to `verified`.
- Successful completion uses normal OpenSpec archive, Git merge, final SHA recording, Completed transition, and lock release in the specified order.
- Cancellation requires explicit user approval and uses `openspec archive <change-id> --yes --skip-specs`, so cancelled delta specs are not merged into permanent specs.
- Snapshot creation and verification use Todoing API operations, not a copy of the active SQLite file.
- Snapshot restore is destructive and requires explicit user approval plus the retained `expected_sha256`; it rejects active task locks, requires the same Project ID/schema, creates a verified safety snapshot under `.todoing/backups/`, and restores only Todoing SQLite.
- Recovery reconciles Todoing, OpenSpec, and Git before retrying. Restore does not undo Git commits or OpenSpec archives.
- Russian and English runbooks use the same API operations, state transitions, lease values, archive modes, and safety gates.

## CI Evidence

- Bilingual runbook regression and OpenSpec validation passed on Manifest run
  [45455193071](https://github.com/zhihus/Manifest/actions/runs/45455193071).
- Real Todoing API + OpenSpec acceptance passed on Manifest run
  [45455395600](https://github.com/zhihus/Manifest/actions/runs/45455395600).
- Acceptance built Todoing from pinned source commit
  `6acca6087fbd4b39ad0dcd5f12db52dc4d84b163` and ran against an isolated
  temporary project.
- The lifecycle covered bootstrap, Project ID, task creation, project-scoped
  OpenSpec reference, approval baseline, lock custody, versioned Review,
  changes-requested idempotency and `revision_count`, rework, approved Review,
  final Git SHA, completion, cancellation, normal OpenSpec archive,
  cancellation archive with `--skip-specs`, snapshot verification, restore,
  and post-restore checks for tasks, reviews, references, final SHA, and outcome.
- Todoing full Linux/Windows CI passed on
  [45454426270](https://github.com/zhihus/todoing-x/actions/runs/45454426270):
  rustfmt, Clippy, full tests, release build, install/smoke tests, SQLite lock
  spike, OpenSpec validation, and JSON Schema validation.
- The full workflow including the archive dependency gate also passed on
  [45455174063](https://github.com/zhihus/todoing-x/actions/runs/45455174063).
- OpenSpec CLI: 1.16.0; Python: 3.12.

## Limitations

The cross-repository acceptance test runs on Linux in an isolated temporary
project. Windows coverage is provided by Todoing's full CI matrix; the
cross-repository lifecycle script itself has not been run on Windows. Manifest
remains documentation and workflow policy, not a runtime daemon. No persistent
user project was initialized or modified.

## Verdict

The runbook, regression checks, and real API/OpenSpec acceptance are verified.
Ready to archive this completed change on the feature branch. No PR, merge, or
push to the default branch was performed.
