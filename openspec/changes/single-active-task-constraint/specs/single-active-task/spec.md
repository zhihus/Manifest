# single-active-task Specification

## Purpose

Define the single-active-task constraint for the Manifest Main Orchestrator:
the agent drives at most one task through execution at a time, and starts a new
task only when no task is active or on explicit user instruction.

## ADDED Requirements

### Requirement: Single active task constraint

The Main Orchestrator MUST NOT start executing another task while a current
task is active. An active task is one whose status is `in_progress`, `review`,
or `verified` — that is, a task that has been started but has not reached a
terminal outcome of `completed` or `cancelled`. Starting a second task is
permitted only after the active task reaches `completed` or `cancelled`, or on
explicit user instruction.

#### Scenario: Second task blocked while first is in progress

- **WHEN** a task is in `in_progress` and the agent is asked to start another task
- **THEN** the agent MUST NOT acquire a lock or move the second task to `in_progress`
- **AND** the agent reports the active task that blocks the new one and waits for the user

#### Scenario: New task allowed after completion

- **WHEN** the current task reaches `completed` or `cancelled`
- **THEN** the agent MAY start executing a new task

#### Scenario: Creating or preparing a task is not execution

- **WHEN** an active task exists and the agent creates a new task in `backlog` or moves it to `ready`
- **THEN** this is allowed and does not violate the constraint
- **AND** the agent still MUST NOT move the new task to `in_progress` until the active task is terminal

#### Scenario: Explicit user exception

- **WHEN** an active task exists and the user explicitly instructs the agent to start another task
- **THEN** the agent MAY start the second task
- **AND** a request to discuss, analyze, draft, or prepare is NOT such an instruction

### Requirement: Method- and actor-independent

The single-active-task constraint MUST apply regardless of who initiated the
task and by what method. It is not scoped to a particular actor, CLI command,
JSON API operation, or invocation path.

#### Scenario: Rule holds for any initiator and method

- **WHEN** a second task is requested by a user, an agent, a subagent, or via any CLI or API path
- **AND** an active task exists
- **THEN** the constraint applies the same way
- **AND** `actor_id` is treated as attribution, not as an exemption