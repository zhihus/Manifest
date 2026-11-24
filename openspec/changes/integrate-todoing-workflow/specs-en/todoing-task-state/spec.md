# Spec Delta

## Purpose

Defines the mapping of an OpenSpec change to a Todoing task: task creation,
statuses, external reference, and dependencies. One OpenSpec change
corresponds to exactly one Todoing task; FR tasks within the change are a
decomposition, not separate Todoing tasks.

## ADDED Requirements

### Requirement: Task and external reference creation

The system SHALL create a Todoing task with status `backlog` and record the
external reference: namespace `openspec.change`, value — the change directory
ID, relation `implements`, scope `project`. The task is created by the user or
proposed by the Analyst in the Backlog.

#### Scenario: Task creation
- WHEN the user creates the task or the Analyst proposes it
- THEN the system creates a Todoing task with status `backlog` and records
  the external reference namespace `openspec.change`

#### Scenario: One change — one task
- WHEN a task is created for an OpenSpec change
- THEN the task corresponds to exactly one change, and FR tasks within the
  change are not created as separate Todoing tasks

### Requirement: Approval of the backlog → ready transition

The `backlog → ready` transition SHALL be confirmed only by the user. An agent
does not consider the task approved on its own. After approval, Manifest
records the baseline through `task.version.approve` when needed.

#### Scenario: Approval by the user
- WHEN the user approves the task
- THEN the system moves the task to `ready`

#### Scenario: Without user approval
- WHEN the user has not approved the task
- THEN the system does not move it to `ready` and does not start execution

### Requirement: Execution and statuses

The system SHALL move an approved task to `in_progress` when execution starts.
Statuses: `backlog → ready → in_progress → review → verified → completed`;
from `review` — to `verified` on approval or back to `in_progress` on remarks.

#### Scenario: Start of execution
- WHEN the Orchestrator acquires the lock for an approved task
- THEN the system moves the task to `in_progress`

#### Scenario: Status cycle
- WHEN the pipeline runs
- THEN statuses transition `in_progress → review → verified → completed`
  (or `review → in_progress` on remarks)

### Requirement: External reference uniqueness

The system SHALL ensure at most one active reference of namespace
`openspec.change` per task and at most one task per change ID. On
cancellation the reference is preserved for audit.

#### Scenario: One reference per task
- WHEN an external reference of namespace `openspec.change` is added to a task
- THEN at most one active reference of this namespace is active on the task

#### Scenario: One change ID — one task
- WHEN a change ID is already bound to a task
- THEN it is not bound to a second task

#### Scenario: Reference preserved on cancellation
- WHEN the task is cancelled
- THEN the external reference is preserved for audit