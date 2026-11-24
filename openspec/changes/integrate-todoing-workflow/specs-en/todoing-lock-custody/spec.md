# Spec Delta

## Purpose

Defines the lock custody model for the integration: the Orchestrator is the
sole holder of the lock token; the model accounts for blocking role sub-agent
execution, during which the Orchestrator cannot send a heartbeat.

## ADDED Requirements

### Requirement: Lock acquisition

The Orchestrator SHALL call `task.lock.acquire` for an approved task, receive
`owner_id`, `lock_token`, `fencing_generation`, `expires_at`, and store the
token only in its protected session state. The token is passed in the envelope
of every owner request. Role sub-agents do not receive a lock token and do not
call Todoing.

#### Scenario: Acquisition
- WHEN the Orchestrator starts executing an approved task
- THEN it calls `task.lock.acquire` and receives the lock token

#### Scenario: Sub-agents do not receive the token
- WHEN the Orchestrator launches a role sub-agent
- THEN the sub-agent does not receive a lock token and does not call Todoing
  directly

### Requirement: Heartbeat only when the Orchestrator is active

The Orchestrator SHALL extend the lease through `task.lock.heartbeat` only
when it is itself active — between sub-agent launches and at gates. During
blocking sub-agent execution the Orchestrator is blocked and does not send a
heartbeat.

#### Scenario: Heartbeat at gates
- WHEN the Orchestrator is active (between sub-agent launches, at gates)
- THEN it sends `task.lock.heartbeat` to extend the lease

#### Scenario: No heartbeat during the sub-agent
- WHEN the Orchestrator is blocked during sub-agent execution
- THEN no heartbeat is sent

### Requirement: Lease covers the hard timeout

The system SHALL configure the lease to 720 s (the sub-agent's hard execution
timeout of 600 s + a 120 s buffer) so the lease survives a full sub-agent run
when the Orchestrator heartbeats immediately before launch.

#### Scenario: Lease survives the sub-agent run
- WHEN the Orchestrator heartbeats immediately before launching the sub-agent
- THEN the lease (720 s) survives the full 600-second sub-agent run

### Requirement: Lock release

The Orchestrator SHALL release the lock through `task.lock.release` when the
task is finished (after `task.status.set` → `completed` or after
cancellation). A repeated `task.lock.release` is not idempotent — it returns
`stale_lock`; a repeat is performed only after ownership is confirmed through
`task.lock.heartbeat`.

#### Scenario: Release
- WHEN the task is finished
- THEN the Orchestrator calls `task.lock.release`

#### Scenario: Ownership check before a repeat release
- WHEN the response to `task.lock.release` is lost and the Orchestrator is
  unsure whether the lock is released
- THEN the Orchestrator verifies ownership through `task.lock.heartbeat`:
  success → repeat `task.lock.release`; `stale_lock` → the lock is already
  released, no action; `lock_expired` → `task.lock.recover` if needed

### Requirement: Recovery after lease expiry

When the lease expires, Todoing does not transfer ownership automatically.
After lease expiry and the recovery grace (60 s), the Orchestrator SHALL call
`task.lock.recover`, obtaining a new token and an increased fencing
generation. The old owner becomes invalid. After recovery the Orchestrator
verifies the current task version before continuing.

#### Scenario: Explicit recovery
- WHEN the lease has expired and the recovery grace (60 s) has passed
- THEN the Orchestrator calls `task.lock.recover` and receives a new token
  with an increased fencing generation

#### Scenario: Old token invalid
- WHEN a recovery is performed
- THEN the old token becomes invalid (`stale_lock`) on any operation and is
  not used

#### Scenario: Competing recovers are atomic
- WHEN two Orchestrators simultaneously call `task.lock.recover` on the same
  task
- THEN only the first succeeds (Exclusive transaction + CAS on
  `fencing_generation`); the second gets `task_locked` because the fresh
  expiry is already in the future

#### Scenario: Version check after recovery
- WHEN the Orchestrator continues working after recovery
- THEN it verifies the current task version before continuing