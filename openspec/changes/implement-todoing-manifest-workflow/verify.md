# Verification: implement-todoing-manifest-workflow

## Scope

Independent review of the bilingual Todoing runbook, its OpenSpec delta, the regression test, and CI wiring. No runtime orchestrator or external Todoing store is implemented by this change; the runbook is the normative consumer procedure.

## Review Results

- Bootstrap preserves Project ID, store, legacy data, and existing configuration; ambiguous or mismatched state is a hard stop.
- The recommended TOML configuration is valid against Todoing's format-version-1 fields and uses a 720-second lease, 180-second heartbeat setting, and 60-second recovery grace.
- Backlog approval remains user-controlled. Dependency readiness is checked before lock acquisition and dispatch.
- The Orchestrator alone calls Todoing and retains lock tokens. Role agents never receive tokens.
- The approved task is moved from `ready` to `in_progress` after lock acquisition and before dispatch.
- Review records are bound to immutable task versions; `changes_requested` and `approved` map to the documented transitions.
- Successful completion uses normal OpenSpec archive (merging delta specs), Git merge, final SHA recording, Completed transition, and lock release in the specified order.
- Cancellation requires explicit user approval and uses `openspec archive <change-id> --yes --skip-specs`, so cancelled delta specs are not merged into permanent specs.
- Recovery reconciles Todoing, OpenSpec, and Git state before retrying and confirms lock ownership before release.
- Russian and English runbooks use the same API operations, state transitions, lease values, archive modes, and safety gates.

## CI Evidence

- Static runbook/configuration validation: passed on Manifest CI run
  [45450867441](https://github.com/zhihus/Manifest/actions/runs/45450867441).
- Real Todoing API + OpenSpec acceptance: passed on run
  [45451516709](https://github.com/zhihus/Manifest/actions/runs/45451516709).
- Acceptance used the Todoing feature branch
  `feature/generic-task-references-review-api`, built from source in the runner.
- The temporary project exercised bootstrap, Project ID, task creation,
  project-scoped OpenSpec reference, approval baseline, lock custody, versioned
  Review, changes_requested idempotency and revision_count, rework, approved
  Review, final Git SHA, completion, cancellation, normal OpenSpec archive,
  cancellation archive with `--skip-specs`, snapshot verification, restore,
  and post-restore data checks.
- Todoing Windows/Linux CI: run
  [45451107043](https://github.com/zhihus/todoing-x/actions/runs/45451107043)
  passed fmt, Clippy, full cargo test, release build, install/smoke tests,
  SQLite lock spike, OpenSpec validation, and JSON Schema validation.
- OpenSpec CLI version: 1.16.0; Python: 3.12.16.

## Limitations

The acceptance test runs in an isolated Linux temporary project. Windows
coverage is provided by Todoing's full CI matrix; the cross-repository lifecycle
script itself has not been run on Windows. Manifest remains documentation and
workflow policy, not a runtime daemon. The acceptance test validates the
documented consumer procedure through the real Todoing API; it does not create a
persistent project store or perform actions in a user's working repository.

## Verdict

No blocking documentation or specification defects found in the reviewed change. Ready for OpenSpec archive on this feature branch; no PR, merge, or push to the default branch was performed.
