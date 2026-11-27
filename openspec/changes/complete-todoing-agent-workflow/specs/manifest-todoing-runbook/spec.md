# Spec Delta: Manifest Todoing Runbook

## ADDED Requirements

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
`6acca6087fbd4b39ad0dcd5f12db52dc4d84b163` or a verified descendant because
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
