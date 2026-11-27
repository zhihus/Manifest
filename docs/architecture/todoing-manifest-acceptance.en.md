# Todoing–Manifest Acceptance Record

**Status:** Accepted for isolated CI/test-project use  
**Manifest tested commit:** `283af9fd28009fcdc5d917290abb8c6052594b29`  
**Todoing pinned commit:** `653788a954d2a120db1beba854308982814d8222`

## CI evidence

- [Todoing Manifest Acceptance](https://github.com/zhihus/Manifest/actions/runs/46054675054) — passed.
- [OpenSpec Validation](https://github.com/zhihus/Manifest/actions/runs/46053248348) — passed. OpenSpec specifications were unchanged after this validation run; subsequent changes were limited to acceptance scripts and CI configuration.

## Stage 5 — end-to-end acceptance

The acceptance workflow successfully completed:

- Bilingual Todoing configuration and runbook regression checks.
- Release build of the pinned Todoing commit.
- Todoing unit tests: **238 passed, 0 failed** (187 + 3 + 48 across test targets).
- Real Todoing API and OpenSpec lifecycle in an isolated temporary Git project.
- Standalone Todoing lifecycle with OpenSpec absent.

The coordinated lifecycle covered exact change/task title mapping, the project-scoped `openspec.change` reference, duplicate-reference conflict handling, baseline approval, locking, independent Review, `changes_requested` revision counting, idempotent Review retry, verification, OpenSpec archive, Git merge SHA, completion, and lock release. Recovery checks covered a repeated Review request and a lost lock-release response. Cancellation used `--skip-specs`; snapshot integrity and restore were also verified.

## Stage 6 — isolated project acceptance

The installer regression suite created disposable Git projects and checked all four Todoing/OpenSpec switch combinations. It verified preservation of existing `AGENTS.md`, Manifest configuration and checksum, OpenSpec configuration/specifications, and existing `.gitignore` rules while adding the `temp/` exclusion.

All installer checks passed. Temporary projects were isolated from user projects and cleaned up by the test scripts.

## Boundaries and limitations

- No real connected project was modified or enabled.
- No PR, merge to `develop`, or production activation was performed.
- User-only approval of `backlog → ready` and cancellation is a documented Main Orchestrator authority rule. Todoing does not technically authenticate the human decision or prevent a separate process from calling its API; this remains a procedural boundary.
- The acceptance test validates API behavior and the documented orchestration contract. It does not prove that an external agent runtime will obey role instructions.

**Conclusion:** Stages 5 and 6 passed for the pinned Todoing build and isolated test projects. Enabling the coordinated mode in a real project remains a separate, explicit decision.
