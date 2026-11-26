# Proposal

## Why

Manifest drives the OpenSpec pipeline (Analyst → Architect → Planner →
Tester → Implementer → Reviewer → Archive) but does not store task state:
there is no source of truth for statuses, locks, version history, and final
commit references. The target integration contract
(`docs/architecture/todoing-contract.ru.md`) is defined, and the universal
Todoing API v1 extensions (external references, Review history,
revision_count, final commit marker) are implemented in Todoing and confirmed
by audit. Integration becomes possible: Manifest consumes the public JSON API
v1 through the `todoing api --json` CLI, and the Main Orchestrator becomes the
sole client of the Todoing API.

Without this change, task statuses, their locks, and history have no single
source of truth, and Todoing ↔ OpenSpec ↔ Git consistency is unverifiable.

## What Changes

- The Main Orchestrator (the main agent session) becomes the sole client of
  the Todoing API; role sub-agents do not receive a lock token and do not call
  Todoing.
- A Project Identity mechanism is introduced: a stable Project ID is stored in
  `.manifest/project-id` and passed in every API request.
- A lock custody model is defined that accounts for blocking role sub-agent
  execution: the Orchestrator cannot maintain a heartbeat while a sub-agent
  runs, so the lease is configured to cover the agent's hard execution
  timeout.
- A store bootstrap procedure is defined: Todoing installation is performed by
  the user, and `store.init` does not overwrite an existing store or legacy
  Markdown data.
- A lifecycle mapping is defined: one Todoing task corresponds to one OpenSpec
  change; statuses, Review, completion, and cancellation are bound to Todoing
  API operations.
- Recovery after partial failure between Todoing, OpenSpec, and Git is
  defined: the systems do not form a transaction, and operation retries are
  idempotent or explicit.

## Capabilities

- `todoing-project-identity` — Project ID generation, validation, and
  protection.
- `todoing-store-bootstrap` — store initialization, configuration, and refusal
  to overwrite legacy data and an existing store.
- `todoing-task-state` — mapping an OpenSpec change to a Todoing task,
  statuses, external reference, and dependencies.
- `todoing-lock-custody` — lock acquisition, heartbeat, release, and recovery
  accounting for blocking sub-agent execution.
- `todoing-review-cycle` — the Review cycle: handoff to review, Review record,
  revision_count, rejection, and approval.
- `todoing-completion-recovery` — final completion, cancellation, and recovery
  after partial failure between the systems.

## Out of scope

- Integration implementation (performed by a separate decision after approval
  of this change).
- Todoing changes: Manifest does not modify Todoing and does not move
  Manifest-specific logic into it.
- Daemon, API wrapper, or hooks/events as a correctness guarantee.
- Automatic migration of legacy data (a separate non-destructive procedure).
- Todoing GUI and cross-project task overview.