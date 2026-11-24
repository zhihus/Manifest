# Design

## Decision

Implement this change as documentation and mechanical validation, not as a runtime orchestrator. Manifest's Orchestrator consumes the runbook in its main session and invokes the installed `todoing` CLI using JSON API v1. Todoing remains the authoritative store for task status, versions, history, locks, reviews, and final commit metadata; Manifest remains authoritative for OpenSpec and Git workflow policy.

## Sources of Truth

- `docs/architecture/todoing-contract.ru.md` — approved consumer contract.
- `openspec/changes/integrate-todoing-workflow/design/bootstrap.md` — bootstrap and Project ID rules.
- `openspec/changes/integrate-todoing-workflow/design/lifecycle.md` — task, lock, review, completion, and cancellation sequences.
- `openspec/changes/integrate-todoing-workflow/design/recovery.md` — reconciliation and partial-failure recovery.
- Todoing `docs/api/v1/operations.md` and JSON schemas on the referenced Todoing feature branch — normative API operations and envelope.

## Deliverables

- Extend `workflow/README.ru.md` and `workflow/README.en.md` with matching Todoing integration sections.
- Add a mechanical runbook regression test that checks critical operation names, ordering constraints, approval gates, and forbidden unsafe shortcuts.
- Add CI execution for the regression test and OpenSpec validation on feature branches.

## Safety Invariants

1. The user alone approves backlog work and cancellation.
2. The Orchestrator is the only Todoing API client and sole custodian of lock tokens.
3. Role agents never receive lock tokens and never call Todoing directly.
4. Existing Project ID, Todoing config, store, and legacy data are never overwritten or reinitialized.
5. Every retry begins with reconciliation of actual Todoing, OpenSpec, and Git state; non-idempotent operations are never blindly repeated.
6. No archive, merge, completion, or cancellation step is inferred from a Git SHA alone.
7. Todoing API requests use the exact v1 envelope and operation contract; no unsupported operation is invented.

## Status Configuration

The runbook must treat the approved six-state workflow as the Manifest policy. It must inspect the installed Todoing configuration and stop on mismatch; it must not silently rewrite an existing config. The runbook must not assume that a CLI command exists when the normative API exposes only a JSON API operation.

## Verification

The regression test is intentionally a documentation contract test, not a substitute for executing Todoing. OpenSpec validation and the regression test run in CI on pushes to feature branches and pull requests to develop. End-to-end execution against a real project store remains a manual acceptance gate because this repository does not contain a disposable external Todoing project fixture.
