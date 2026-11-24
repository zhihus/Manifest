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

- Commit: `0f5b0b3eb616c9eb01e82a3f94b49f9466531b9e`
- GitHub Actions: [run 45425608232](https://github.com/zhihus/Manifest/actions/runs/45425608232)
- Bilingual runbook regression test: passed.
- Python 3.12 TOML parsing and parity test: passed; both configuration examples match and satisfy the expected status graph and lock values.
- `openspec validate --all`: passed.
- OpenSpec CLI version in CI: 1.16.0.

## Limitations

The regression test validates the written contract, not an end-to-end session against a real Todoing project store. Manifest is documentation/orchestration policy rather than a runtime daemon; the first real-project bootstrap and lifecycle run remain an acceptance check when local project access is restored.

## Verdict

No blocking documentation or specification defects found in the reviewed change. Ready for OpenSpec archive on this feature branch; no PR, merge, or push to the default branch was performed.
