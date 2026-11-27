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

### Requirement: One-to-one OpenSpec and Todoing mapping

When both OpenSpec and Todoing are enabled, each OpenSpec change MUST be represented by exactly one Todoing task. The Orchestrator MUST create that task in `backlog`, set its title to the exact OpenSpec change directory ID, and add a project-scoped external reference with namespace `openspec.change`, value equal to that exact change directory ID, relation `implements`, and scope `project`. The Orchestrator MUST reuse the existing task for that change rather than create a duplicate.

All implementation decomposition MUST remain inside that change's `tasks.md`. FR entries, checkboxes, implementation steps, and other work items in `tasks.md` MUST NOT become separate Todoing tasks. Todoing tracks the OpenSpec change as a whole; it does not mirror its internal work breakdown.

#### Scenario: Register an OpenSpec change

- GIVEN a new OpenSpec change exists and no Todoing task is linked to it
- WHEN the Orchestrator registers the change
- THEN it creates exactly one Todoing task in `backlog`
- AND sets the Todoing task title to the exact change directory ID
- AND adds the project-scoped `openspec.change` reference using the exact change directory ID and relation `implements`

#### Scenario: Keep FR decomposition in tasks.md

- GIVEN an OpenSpec change has multiple FR entries or implementation checkboxes in `tasks.md`
- WHEN the Orchestrator plans or dispatches the work
- THEN those entries remain internal work items in `tasks.md`
- AND it does not create separate Todoing tasks for FR entries, checkboxes, or implementation steps

#### Scenario: Reuse the task for an existing change

- GIVEN a Todoing task already has the project-scoped `openspec.change` reference for the change
- WHEN the Orchestrator registers or resumes that change
- THEN it reuses the linked task and does not create another Todoing task

### Requirement: User-controlled task approval and baseline

The runbook MUST preserve the user's exclusive authority to authorize execution. A change-tracking Todoing task MUST remain in `backlog` until the user explicitly approves work and authorizes the transition to `ready`. After that transition, the Orchestrator MUST record the current task version as the approved baseline using `task.version.approve` before acquiring the execution lock, dispatching an agent, or moving the task to `in_progress`. A task MUST NOT enter execution without both user authorization and a recorded baseline.

#### Scenario: Unapproved task

- GIVEN a task is in `backlog`
- WHEN an agent proposes starting implementation without explicit user authorization
- THEN the Orchestrator refuses to transition it to `ready`, acquire a lock, or dispatch implementation

#### Scenario: Approve and baseline a change

- GIVEN a change-tracking task is in `backlog`
- WHEN the user explicitly authorizes its execution
- THEN the Orchestrator transitions the task to `ready`
- AND records the current task version with `task.version.approve`
- AND only then may it acquire the lock and start execution

### Requirement: Gate execution on dependencies

The Orchestrator MUST inspect each task's dependencies before dispatch. Every prerequisite MUST have outcome `completed`. If a prerequisite is locked, missing, or cannot be verified, the Orchestrator MUST stop and MUST NOT start implementation. Todoing stores dependency edges and prevents cycles; Manifest owns readiness policy.

#### Scenario: Block work on an incomplete prerequisite

- GIVEN an approved task depends on a task whose outcome is not `completed`
- WHEN the Orchestrator prepares to dispatch an implementation agent
- THEN it does not acquire the work lock or dispatch the agent
- AND it reports the blocking prerequisite

### Requirement: Orchestrator-owned lock custody

The runbook MUST define the Orchestrator's procedural responsibility for coordinating Todoing calls and retaining the raw lock token. The task MUST have an explicitly user-approved baseline and all prerequisites MUST have outcome `completed` before lock acquisition. After acquiring the lock, the Orchestrator MUST immediately transition `ready → in_progress` before dispatch. Role agents MUST NOT receive the token or independently invoke Todoing. The Orchestrator MUST heartbeat immediately before each blocking role-agent run and MUST NOT heartbeat while that agent is executing. It MUST use the current owner ID and fencing generation for owner operations, stop using a token after `stale_lock`, and release the lock only after completion/cancellation and cross-system reconciliation. These are procedural boundaries, not technical isolation; the runtime is not required to block direct CLI/API access by role agents.

#### Scenario: Start approved work

- GIVEN the user approved the task, its current version is recorded with `task.version.approve`, and all prerequisites have outcome `completed`
- WHEN the Orchestrator acquires the task lock
- THEN it immediately transitions the task from `ready` to `in_progress`
- AND keeps the lock token outside the agent prompt and environment

#### Scenario: Heartbeat before a blocking agent run

- GIVEN the Orchestrator owns a valid task lock
- WHEN it is about to dispatch a blocking role-agent run
- THEN it calls `task.lock.heartbeat` immediately before dispatch
- AND it does not heartbeat while the role agent is executing

#### Scenario: Role agent execution

- GIVEN the Orchestrator owns a valid task lock
- WHEN it dispatches a role agent
- THEN the token remains in protected Orchestrator session state and is not included in the agent's prompt or environment
- AND the role agent does not call Todoing directly

#### Scenario: Direct Todoing access is not technically blocked

- GIVEN the runtime permits a role agent to invoke the Todoing CLI/API directly
- WHEN the integration's authority boundary is assessed
- THEN the runbook does not claim that direct access is technically prevented
- AND compliance is assessed against the procedural instructions and observed agent actions

### Requirement: Independent Review and revision loop

The runbook MUST require a separate Reviewer role/session to inspect the exact result and task version independently from the Implementer. Before review dispatch, the Orchestrator MUST transition `in_progress → review`. It MUST append a Review record with stable `review_id`, exact `version_no`, reviewer identity, outcome, and ordered comments. On `approved`, it MUST transition `review → verified`. On `changes_requested`, Todoing MUST atomically append the Review and increment `revision_count` exactly once; the Orchestrator MUST transition `review → in_progress` and return the findings for correction. After corrections, a new independent review cycle MUST occur. Review records MUST be immutable and bound to the reviewed task version.

#### Scenario: Approve an independently reviewed result

- GIVEN an independent Reviewer has approved the exact task version
- WHEN the Orchestrator records the Review
- THEN Todoing appends an `approved` Review record
- AND the Orchestrator transitions the task to `verified`

#### Scenario: Review requests changes

- GIVEN a Reviewer has completed review of a specific task version
- WHEN the Orchestrator records a `changes_requested` review
- THEN Todoing appends the review with a stable review ID and exact version number
- AND increments `revision_count` exactly once
- AND the Orchestrator transitions the task to `in_progress` for correction

#### Scenario: Repeat review after correction

- GIVEN a `changes_requested` Review has returned the task to `in_progress`
- WHEN the Implementer corrects the result and the work is reviewed again
- THEN the Orchestrator appends a new Review record for the exact new version
- AND preserves all previous Review records and the accumulated `revision_count`

### Requirement: Verified completion and user-approved cancellation

For coordinated Todoing/OpenSpec work, the runbook MUST define the ordered success sequence: Review approved and task Verified; acceptance checks across Todoing, OpenSpec, and Git; `openspec archive <change-id> --yes` to merge delta specs; Git merge; `task.commit.finalize` with the actual final merge SHA; transition to Completed; then lock release. Standalone Todoing work MUST omit OpenSpec archive. Cancellation MUST require explicit user confirmation, call `task.cancel`, archive a linked OpenSpec change with `openspec archive <change-id> --yes --skip-specs` without merging delta specs, retain the external reference, then release the lock. The Orchestrator MUST NOT treat archiving alone as cancellation.

#### Scenario: Successful coordinated completion

- GIVEN review is approved and acceptance checks pass
- WHEN the Orchestrator completes the change
- THEN it archives OpenSpec, merges Git, records the actual final merge SHA, transitions Todoing to Completed, and releases the lock in that order

#### Scenario: Cancellation without user approval

- GIVEN an agent recommends cancellation
- WHEN the user has not confirmed it
- THEN the Orchestrator does not call `task.cancel`, change the task outcome, or archive the change

#### Scenario: User-approved cancellation

- GIVEN the user explicitly confirms cancellation
- WHEN the Orchestrator cancels the linked task
- THEN it records outcome `cancelled`
- AND archives the OpenSpec change without merging delta specs
- AND retains the external reference
- AND releases the lock after reconciling the operations

### Requirement: Reconciliation before recovery

The runbook MUST require reading actual Todoing, OpenSpec, and Git state before any retry after interruption. Todoing reconciliation MUST inspect `task.get`, `task.version.list`, `task.history.list`, `task.review.list`, `task.external-ref.list`, and `task.dependency.list`; OpenSpec reconciliation MUST inspect the change and archive state; Git reconciliation MUST inspect branch, merge, and commit SHAs. It MUST distinguish idempotent from non-idempotent operations and MUST NOT blindly repeat `task.cancel`, `task.lock.release`, or OpenSpec archive. It MUST describe recovery for partial failure after archive, after Git merge, after finalization, after completion, during lock release, after lease expiry, and during cancellation. Recovery MUST use the current fencing generation and MUST stop for user escalation if the cross-system state is ambiguous.

#### Scenario: Lost Review response

- GIVEN the `task.review.add` response was lost
- WHEN the Orchestrator resumes
- THEN it inspects `task.review.list` before retrying
- AND does not append a duplicate when the same review ID and payload are already present
- AND performs only the missing status transition after reconciling task state

#### Scenario: Lost lock-release response

- GIVEN the release response was lost
- WHEN the Orchestrator resumes
- THEN it checks ownership with `task.lock.heartbeat`
- AND retries release only after successful ownership confirmation

#### Scenario: Failure after OpenSpec archive

- GIVEN the OpenSpec change is already archived and permanent specs contain the delta
- WHEN Git merge has not yet completed
- THEN the Orchestrator does not archive again
- AND reconciles and continues with Git merge

#### Scenario: Failure after Git merge

- GIVEN Git merge completed but `task.commit.finalize` was not recorded
- WHEN the Orchestrator resumes
- THEN it obtains the actual merge SHA and records it with `task.commit.finalize`

#### Scenario: Failure after final commit marker

- GIVEN the final commit marker is recorded but the task is still `verified`
- WHEN the Orchestrator resumes
- THEN it verifies that the marker matches the actual merge SHA
- AND performs only the missing transition to `completed` after final acceptance checks

#### Scenario: Failure after task completion

- GIVEN the task is already `completed` but the lock may still be held
- WHEN the Orchestrator resumes
- THEN it does not repeat the completion transition
- AND confirms ownership before attempting lock release

#### Scenario: Lease expires during agent execution

- GIVEN the task lease expires while a role agent is running
- WHEN the recovery grace period has elapsed
- THEN the Orchestrator uses `task.lock.recover` to obtain a new token and fencing generation
- AND re-reads the task version and reconciles Git/OpenSpec artifacts before resuming

#### Scenario: Partial cancellation

- GIVEN `task.cancel` succeeded but OpenSpec archive or lock release did not complete
- WHEN the Orchestrator resumes
- THEN it does not repeat `task.cancel`
- AND performs only the missing archive and release steps after reconciling state
- AND never merges the cancelled change's delta specs into permanent specs

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
- THEN it records the accepted final Git SHA with `task.commit.finalize`
- AND moves the task to `completed` with `task.status.set`
- AND releases the lock with `task.lock.release`
- AND does not create an `openspec.change` reference or invoke OpenSpec archive

#### Scenario: Cancel without OpenSpec

- GIVEN the user explicitly confirms cancellation
- WHEN the Orchestrator cancels the task
- THEN it records outcome `cancelled` and releases the lock
- AND it does not invoke OpenSpec archive

### Requirement: Agent skill exposes runtime Todoing management

The distributed Manifest agent skill MUST provide a runtime Todoing procedure that
can be invoked after project connection. It MUST NOT depend on project context files
being enabled or copied into the connected project.

#### Scenario: Manage standalone Todoing tasks after connection

- GIVEN the project is connected, Todoing is enabled, and OpenSpec is disabled
- WHEN the user asks the agent to create, update, execute, review, or complete work
- THEN the agent skill loads the Todoing runtime workflow reference
- AND the agent follows the standalone Todoing lifecycle without rerunning initialization

#### Scenario: Manage coordinated Todoing and OpenSpec work after connection

- GIVEN the project is connected and both Todoing and OpenSpec are enabled
- WHEN the user asks the agent to prepare or execute an OpenSpec change
- THEN the agent skill loads the coordinated Todoing/OpenSpec workflow
- AND registers exactly one Backlog Todoing task with the exact change ID and project-scoped `openspec.change` reference
- AND keeps all implementation decomposition in the change's `tasks.md`
- AND requires explicit user authorization and an approved task-version baseline before execution

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
