# Proposal

## Why

The approved `integrate-todoing-workflow` change defines the Manifest ↔ Todoing contract but explicitly leaves operational implementation out of scope. The current workflow protocol still lacks an executable runbook for bootstrap, task ownership, lock custody, review, completion, cancellation, and recovery. Without that runbook, the contract cannot be applied consistently by the Orchestrator.

## What Changes

- Implement the approved integration contract as a normative Orchestrator runbook in Russian and English.
- Define safe bootstrap and Project ID handling without overwriting existing Todoing configuration or stores.
- Define the exact JSON API v1 request sequence for task lifecycle, locks, reviews, Git finalization, cancellation, and recovery.
- Preserve the user-approval gates and the single-Orchestrator ownership of lock tokens.
- Add mechanical checks for required runbook invariants and validate the OpenSpec change.

## Capabilities

- `manifest-todoing-runbook` — operational procedure for the Orchestrator to use Todoing as the task-state source of truth.

## Out of Scope

- Changes to Todoing source code or API.
- Automatic installation or update of the Todoing binary.
- A daemon, background service, hooks, event bus, or parallel agent execution.
- Automatic migration of legacy Markdown task data.
- Changes to permanent OpenSpec specifications before verification and archive.
- Changes to Manifest initialization semantics unrelated to the integration runbook.
