# Spec Delta

## Purpose

Defines the final completion of a task, cancellation, and recovery after
partial failure between Todoing, OpenSpec, and Git. The systems do not form a
transaction; operation retries are idempotent or explicit.

## ADDED Requirements

### Requirement: Successful completion

Successful completion SHALL be performed in the sequence: status `verified`
(Review approved) → acceptance checks → standard OpenSpec archive → Git merge
per Manifest policy → `task.commit.finalize` with the final merge SHA →
`task.status.set` → `completed` (terminal transition) → lock release. The
Final Commit SHA is a traceability marker, not proof of successful acceptance.

#### Scenario: Completion sequence
- WHEN the `verified` status is reached
- THEN the system performs the acceptance checks, the OpenSpec archive, the
  Git merge, `task.commit.finalize` with the final merge SHA,
  `task.status.set` → `completed`, and the lock release

#### Scenario: Terminal transition sets the outcome
- WHEN the system performs `task.status.set` → `completed`
- THEN the transition itself sets the outcome `completed` (the status is
  mapped to the outcome in `config.toml`); a separate `task.complete` call is
  not made in the success path, and a repeated `task.complete` is rejected as
  `task_terminal`

#### Scenario: Final Commit SHA — marker
- WHEN the final merge SHA is recorded through `task.commit.finalize`
- THEN the SHA serves as a traceability marker, not proof of acceptance

### Requirement: Cancellation

Only the user SHALL confirm the cancellation. After confirmation the
Orchestrator sets the outcome `cancelled` through `task.cancel` (terminal
outcome; a repeat → `task_terminal`), archives the OpenSpec change through the
standard Archive mechanism (delta specs are not merged into permanent specs),
and releases the lock through `task.lock.release`. The external reference is
preserved for audit.

#### Scenario: Confirmed cancellation
- WHEN the user confirms the cancellation
- THEN the Orchestrator calls `task.cancel` (outcome `cancelled`), archives
  the OpenSpec change (without merging the delta specs), and releases the lock
  through `task.lock.release`

#### Scenario: Lock release after cancellation
- WHEN the outcome `cancelled` is set and the change is archived
- THEN the Orchestrator releases the lock through `task.lock.release`
  (permitted after the terminal outcome)

#### Scenario: Without user confirmation
- WHEN the user has not confirmed the cancellation
- THEN the system does not set the outcome `cancelled` and does not archive
  the change

#### Scenario: Reference preserved on cancellation
- WHEN the task is cancelled
- THEN the external reference is preserved for audit

### Requirement: Recovery after partial failure

The system SHALL recover the state after a partial failure by reconciling the
actual states of Todoing, OpenSpec, and Git before repeating operations.
Blind retries of non-idempotent operations are forbidden.

#### Scenario: Reconciliation before retry
- WHEN an operation did not complete due to a failure
- THEN the system reconciles the actual states of Todoing, OpenSpec, and Git
  and determines which operations are still pending

#### Scenario: Idempotent retry
- WHEN an operation is idempotent (for example, `task.commit.finalize` with
  the same SHA)
- THEN the system repeats it safely

#### Scenario: Prohibition of blind retry
- WHEN an operation is non-idempotent
- THEN the system does not repeat it without an explicit recovery and a state
  reconciliation

### Requirement: Recovery scenarios

The system SHALL provide recovery for the partial-failure scenarios defined in
`design/recovery.md` (S1–S5): between the OpenSpec archive and the Git merge,
between the Git merge and `task.commit.finalize`, between the transition to
`completed` and the lock release, on lease expiry during the sub-agent, and on
cancellation.

#### Scenario: Failure between the archive and the merge
- WHEN the change is already archived but the Git merge is not performed
- THEN the system performs the Git merge, then `task.commit.finalize` with
  the SHA and `task.status.set` → `completed`, without repeating the archive

#### Scenario: Failure during locking
- WHEN the lease expired during sub-agent execution
- THEN after the lease and the recovery grace the Orchestrator performs
  `task.lock.recover` and verifies the current task version