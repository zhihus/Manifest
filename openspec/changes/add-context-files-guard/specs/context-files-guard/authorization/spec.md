## Purpose

Governs how a user approval is captured, how the Guard issues a single-use authorization bound to an exact change, and how state transitions, expiry, replay prevention and recovery work.

## ADDED Requirements

### Requirement: One approval covers one exact change
The Guard SHALL issue a short-lived, single-use authorization bound to repository, branch, base commit, paths, operations, blob hashes and diff hash. Any change to base commit or content SHALL invalidate the authorization and require a new approval.

#### Scenario: Content differs from approved diff
- **WHEN** staged protected content differs from the approved diff (different blob or diff hash)
- **THEN** the Guard rejects the operation and no authorization is consumed

#### Scenario: Base commit moved
- **WHEN** the base commit of the task branch changed after approval
- **THEN** the authorization is invalid and a new approval is required

### Requirement: Authorization state machine
The Guard SHALL maintain atomic authorization states `PROPOSED → APPROVAL_PENDING → APPROVED → AUTHORIZED → COMMIT_PENDING → CONSUMED` with terminal states `REJECTED`, `EXPIRED`, `INVALIDATED` and recovery state `RECOVERY_REQUIRED`. State transitions MUST be atomic to prevent replay and concurrency.

#### Scenario: Rejection
- **WHEN** the user rejects the approval prompt or it times out
- **THEN** the authorization ends in `REJECTED` and no protected operation is permitted

#### Scenario: Expiry
- **WHEN** a never-consumed authorization reaches its expiry time
- **THEN** it transitions to `EXPIRED` and can no longer authorize any operation

### Requirement: Authorization consumed only after matching commit
The Guard SHALL consume authorization only after post-commit verification against a durable pre-commit receipt confirms the parent commit, tree and diff match the authorization. A failed commit SHALL retain the authorization until expiry.

#### Scenario: Successful protected commit
- **WHEN** a commit containing exactly the approved protected change is created on the task branch and post-commit verification passes
- **THEN** the authorization transitions to `CONSUMED` and cannot authorize another change

#### Scenario: Failed commit
- **WHEN** the commit fails after pre-commit verification passed
- **THEN** the authorization remains valid until expiry and the change state is recoverable

### Requirement: Ambiguous state blocks protected operations
The Guard SHALL block all protected operations pending recovery when the authorization state is ambiguous or interrupted.

#### Scenario: Interrupted after commit
- **WHEN** the process is interrupted between commit and post-commit verification
- **THEN** protected operations are blocked with a `RECOVERY_REQUIRED` indication until recovery completes

### Requirement: Runtime state location
The Guard SHALL store runtime authorization state outside the repository in a per-user location (`%LOCALAPPDATA%\ContextFilesGuard\`), and SHALL document that same-user secrets do not constitute an OS sandbox.

#### Scenario: State is not in the repository
- **WHEN** the Guard records an authorization
- **THEN** no authorization state file appears in the repository working tree or history
