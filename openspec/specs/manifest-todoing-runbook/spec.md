# manifest-todoing-runbook Specification

## Purpose
Governs the Manifest–Todoing integration runbook: how the Main
Orchestrator bootstraps the Todoing store, holds the task lock, and
drives each task through approval, dependency gating, review, verified
completion, and recovery via the Todoing JSON API, with the user
retaining exclusive authority to approve work.

## Requirements

### Requirement: Safe Todoing bootstrap

The runbook MUST require the Orchestrator to verify the installed Todoing binary before bootstrap. For an existing store, it MUST verify the JSON API with `store.info` and `store.verify`; for a new store, it MUST verify the API immediately after the single `store.init` call using those operations. It MUST generate a Project ID only when both the ID file and store are absent. It MUST stop if a store exists but the Project ID is missing, if the stored ID differs, or if an existing configuration is incompatible. It MUST NOT overwrite an existing configuration, database, or legacy task data.

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

### Requirement: Gate execution on dependencies

The Orchestrator MUST inspect each task's dependencies before dispatch. Every prerequisite MUST have outcome `completed`. If a prerequisite is locked, missing, or cannot be verified, the Orchestrator MUST stop and MUST NOT start implementation. Todoing stores dependency edges and prevents cycles; Manifest owns readiness policy.

#### Scenario: Block work on an incomplete prerequisite

- GIVEN an approved task depends on a task whose outcome is not `completed`
- WHEN the Orchestrator prepares to dispatch an implementation agent
- THEN it does not acquire the work lock or dispatch the agent
- AND it reports the blocking prerequisite

### Requirement: Orchestrator-owned lock custody

The runbook MUST define the Orchestrator's procedural responsibility for coordinating Todoing calls and retaining the raw lock token. Role agents MUST follow the procedural boundary: they must not independently invoke Todoing or receive the token. This is not technical isolation, and the runtime is not required to block direct CLI/API access by role agents. Compliance is evaluated from the recorded and observable actions of the agents, not from an access-control test. The runbook MUST also specify a 720-second lease, heartbeat immediately before each blocking role-agent run, no heartbeat while that agent is executing, and explicit recovery after lease expiry plus grace.

#### Scenario: Role agent execution

- GIVEN the Orchestrator owns a valid task lock
- WHEN it dispatches a role agent
- THEN the token remains in protected Orchestrator session state and is not included in the agent's prompt or environment
- AND the runbook identifies this as a procedural boundary rather than a technical access restriction

#### Scenario: Direct Todoing access is not technically blocked

- GIVEN the runtime permits a role agent to invoke the Todoing CLI/API directly
- WHEN the integration's authority boundary is assessed
- THEN the runbook does not claim that direct access is technically prevented
- AND compliance is assessed against the procedural instructions and observed agent actions

### Requirement: Traceable task lifecycle and review

The runbook MUST define the approved status transitions, the project-scoped `openspec.change` external reference, version baseline approval, and append-only Review records bound to the reviewed version. It MUST specify that `changes_requested` increments Todoing `revision_count` once and returns the task to `in_progress`, while `approved` moves it to `verified`.

#### Scenario: Start approved work

- GIVEN the user approved a task and all prerequisites have outcome `completed`
- WHEN the Orchestrator acquires the task lock
- THEN it transitions the task from `ready` to `in_progress` before dispatching an implementation agent
- AND keeps the lock token outside the agent prompt and environment

#### Scenario: Review requests changes

- GIVEN a Reviewer has completed review of a specific task version
- WHEN the Orchestrator records a `changes_requested` review
- THEN it stores the review with a stable review ID and exact version number, and Todoing increments `revision_count` once

### Requirement: Verified completion and user-approved cancellation

The runbook MUST define the ordered success sequence: Verified, acceptance checks, `openspec archive <change-id> --yes` (merge delta specs), Git merge, `task.commit.finalize`, transition to Completed, then lock release. Cancellation MUST require explicit user confirmation, set cancelled outcome, archive the OpenSpec change with `openspec archive <change-id> --yes --skip-specs` without merging delta specs, then release the lock. The external reference MUST be retained.

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

### Requirement: Standalone Todoing task lifecycle

When `components.todoing.enabled` is true and
`components.openspec.enabled` is false, the Main Orchestrator MUST manage
standalone project tasks through Todoing without requiring OpenSpec changes,
external references, or archive operations.

#### Scenario: Discover and reuse an existing task

- GIVEN Todoing is enabled and OpenSpec is disabled
- WHEN the Orchestrator starts work on a user request
- THEN it lists active tasks and reuses a matching task instead of creating a duplicate

#### Scenario: Create an independent task

- GIVEN no matching active task exists
- WHEN the user requests an independently meaningful unit of work
- THEN the Orchestrator creates one task in `backlog`
- AND keeps implementation substeps inside that task

#### Scenario: Update an existing task

- GIVEN a matching active task already exists
- WHEN its title, goal, boundaries, or acceptance criteria need correction
- THEN the Orchestrator reads it and updates only the supported fields through
  `task.update`
- AND a material change after approval requires explicit user re-approval and a
  new approved baseline

#### Scenario: Gate on task dependencies

- GIVEN a task has prerequisite tasks
- WHEN the Orchestrator prepares to start it
- THEN it verifies every prerequisite through `task.dependency.list`
- AND it does not dispatch work unless every prerequisite outcome is `completed`

#### Scenario: Preserve user approval

- GIVEN a task is in `backlog`
- WHEN the user has not explicitly instructed the Orchestrator to execute it
- THEN the task remains in `backlog`
- AND no implementation is dispatched

#### Scenario: Execute an approved task

- GIVEN the user explicitly instructed execution and all prerequisites have outcome
  `completed`
- WHEN the Orchestrator starts work
- THEN it records the approved version baseline, acquires the task lock, and moves
  the task to `in_progress`

#### Scenario: Complete without OpenSpec

- GIVEN an independent task has passed Review and acceptance checks
- WHEN the Orchestrator completes it
- THEN it records the final Git commit, moves the task to `completed`, and releases
  the lock
- AND it does not create an `openspec.change` reference or invoke OpenSpec archive

#### Scenario: Cancel without OpenSpec

- GIVEN the user explicitly confirms cancellation
- WHEN the Orchestrator cancels the task
- THEN it records outcome `cancelled` and releases the lock
- AND it does not invoke OpenSpec archive

### Requirement: Agent skill exposes runtime Todoing management

The distributed Manifest agent skill MUST provide a runtime Todoing procedure that
can be invoked after project connection. It MUST NOT depend on project context files
being enabled or copied into the connected project.

#### Scenario: Manage tasks after connection

- GIVEN the project is connected, Todoing is enabled, and OpenSpec is disabled
- WHEN the user asks the agent to create, update, execute, review, or complete work
- THEN the agent skill loads the Todoing runtime workflow reference
- AND the agent follows the standalone Todoing lifecycle without rerunning initialization

#### Scenario: OpenSpec is enabled while stage 2 is frozen

- GIVEN Todoing and OpenSpec are both enabled
- WHEN the stage-1 Todoing skill is invoked
- THEN it stops before cross-system operations
- AND reports that Todoing/OpenSpec coordination is outside the current stage

### Requirement: Compatible Todoing API build

The full Manifest Todoing workflow MUST use Todoing source commit
`653788a954d2a120db1beba854308982814d8222` or a verified descendant because
the required external-reference, Review, and final-commit operations are absent
from the current public Todoing `main` branch.

#### Scenario: Incompatible Todoing build

- GIVEN the installed binary does not support the required API operations
- WHEN the Orchestrator performs the Todoing preflight
- THEN it stops before starting the workflow and reports the incompatible build

### Requirement: Honest role-access boundary

The Main Orchestrator MUST be the only Todoing API client in the Manifest workflow.
Role agents MUST NOT receive lock tokens or be instructed to invoke Todoing directly.
The Orchestrator MUST NOT describe `actor_id` as authentication or claim that
workflow instructions alone technically prevent direct CLI access.

#### Scenario: Role agent has direct CLI access

- GIVEN the runtime permits a role agent to invoke the Todoing binary directly
- WHEN the integration's access boundary is assessed
- THEN the Orchestrator reports that role isolation is procedural rather than
  technically enforced
