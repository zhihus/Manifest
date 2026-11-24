# Specification: Manifest Todoing Runbook

## ADDED Requirements

### Requirement: Safe Todoing bootstrap

The runbook MUST require the Orchestrator to verify the installed Todoing binary and JSON API before bootstrap. It MUST generate a Project ID only when both the ID file and store are absent. It MUST stop if a store exists but the Project ID is missing, if the stored ID differs, or if an existing configuration is incompatible. It MUST NOT overwrite an existing configuration, database, or legacy task data.

#### Scenario: New project bootstrap

- GIVEN Todoing is installed and no Project ID, SQLite store, or legacy task data exists
- WHEN the Orchestrator bootstraps the integration
- THEN it creates and atomically persists a UUIDv4 Project ID, validates or creates the recommended configuration without overwriting files, and initializes the store once

#### Scenario: Existing store without identity

- GIVEN a Todoing store exists but `.manifest/project-id` is missing
- WHEN bootstrap is requested
- THEN the Orchestrator stops and requests explicit recovery; it does not generate a replacement ID or call `store.init`

### Requirement: User-controlled task approval

The runbook MUST map one OpenSpec change to one Todoing task and MUST preserve the user's exclusive authority to approve work. Analyst-created tasks remain in Backlog until the user approves transition to Ready. A task MUST NOT enter execution without that approval.

#### Scenario: Unapproved task

- GIVEN a task is in Backlog
- WHEN an agent proposes starting implementation
- THEN the Orchestrator refuses to acquire a lock or dispatch implementation until the user approves the task

### Requirement: Orchestrator-owned lock custody

The runbook MUST specify that only the Orchestrator calls Todoing and holds the raw lock token. It MUST specify a 720-second lease, heartbeat immediately before each blocking role-agent run, no heartbeat while that agent is executing, and explicit recovery after lease expiry plus grace. Role agents MUST NOT receive the token.

#### Scenario: Role agent execution

- GIVEN the Orchestrator owns a valid task lock
- WHEN it dispatches a role agent
- THEN the token remains in protected Orchestrator session state and is not included in the agent's prompt or environment

### Requirement: Traceable task lifecycle and review

The runbook MUST define the approved status transitions, the project-scoped `openspec.change` external reference, version baseline approval, and append-only Review records bound to the reviewed version. It MUST specify that `changes_requested` increments Todoing `revision_count` once and returns the task to `in_progress`, while `approved` moves it to `verified`.

#### Scenario: Review requests changes

- GIVEN a Reviewer has completed review of a specific task version
- WHEN the Orchestrator records a `changes_requested` review
- THEN it stores the review with a stable review ID and exact version number, and Todoing increments `revision_count` once

### Requirement: Verified completion and user-approved cancellation

The runbook MUST define the ordered success sequence: Verified, acceptance checks, OpenSpec archive, Git merge, `task.commit.finalize`, transition to Completed, then lock release. Cancellation MUST require explicit user confirmation, set cancelled outcome, archive the OpenSpec change without merging delta specs, then release the lock. The external reference MUST be retained.

#### Scenario: Successful completion

- GIVEN review is approved and acceptance checks pass
- WHEN the Orchestrator completes the change
- THEN it archives OpenSpec, merges Git, records the final merge SHA, transitions Todoing to Completed, and releases the lock in that order

#### Scenario: Cancellation

- GIVEN an agent recommends cancellation
- WHEN the user has not confirmed it
- THEN the Orchestrator does not cancel or archive the change

### Requirement: Reconciliation before recovery

The runbook MUST require reading actual Todoing, OpenSpec, and Git state before any retry after interruption. It MUST distinguish idempotent from non-idempotent operations and MUST NOT blindly repeat `task.cancel` or `task.lock.release`. It MUST describe recovery for partial failure around archive, merge, finalization, completion, lock release, and cancellation.

#### Scenario: Lost lock-release response

- GIVEN the release response was lost
- WHEN the Orchestrator resumes
- THEN it checks ownership with `task.lock.heartbeat` and retries release only after successful ownership confirmation
