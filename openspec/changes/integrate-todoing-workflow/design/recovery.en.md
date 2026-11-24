# Design — Recovery After Partial Failure

## Principles

- Todoing, OpenSpec, and Git do not form a transaction. Each change is a
  verifiable step with an idempotent retry or an explicit recovery.
- **No blind retries of non-idempotent operations.** Before repeating an
  operation, the Orchestrator reconciles the actual state of the
  corresponding system.
- Recovery starts by reading the current state of all three systems (Todoing:
  status, outcome, versions; OpenSpec: change presence/archival, permanent
  specs; Git: branch, merge, SHA) and only then deciding which operations are
  still pending.
- **Lock state is not read by a public operation.** Todoing provides no
  read-only lock-state operation. The Orchestrator knows it holds the lock
  because it acquired the token itself; the lock's currency is verified by an
  operation that validates the grant (e.g., `task.lock.heartbeat`): success —
  the lock is active and held by this token, `stale_lock` — the token is no
  longer valid (the lock may have been released or taken over by recovery),
  `lock_expired` — the lease expired.

## States and their reconciliation

| Step | Fact in Todoing | Fact in OpenSpec | Fact in Git |
|---|---|---|---|
| Task approved | status `ready` | change exists | — |
| Execution | status `in_progress`, lock active | — | change branch |
| Review | status `review` | — | — |
| Approval | status `verified` | — | — |
| Archive | — | change in `archive/`, permanent specs updated | — |
| Merge | — | — | merge commit |
| Finalize | commit reference with SHA | — | SHA |
| Complete | status `completed`, outcome `completed` | — | — |

## Recovery scenarios

### S1. Failure between OpenSpec archive and Git merge

- Fact: the change is already in `archive/`, permanent specs are updated, the
  merge is not performed.
- Action: do not repeat the archive (idempotent: the change is already
  archived). Perform the Git merge. After the merge — `task.commit.finalize`
  with the SHA, then `task.status.set` → `completed`.
- Verification: the merge commit SHA exists; `task.commit.finalize` is a
  no-op on a repeat with the same SHA.

### S2. Failure between Git merge and `task.commit.finalize`

- Fact: the merge is performed, the commit reference is not recorded.
- Action: obtain the merge commit SHA, perform `task.commit.finalize`. A
  repeat with the same SHA is a no-op. Then `task.status.set` → `completed`.

### S3. Failure between the transition to `completed` and lock release

- Fact: status `completed`, outcome `completed`, the lock is still active or
  the release is unconfirmed (the response to `task.lock.release` was lost).
- There is no public lock-state-read operation; the currency of ownership is
  verified by an operation that validates the grant — `task.lock.heartbeat`.
- Action: the Orchestrator sends `task.lock.heartbeat`:
  - a successful heartbeat confirms a live token (the lock is active and held
    by this token) → perform `task.lock.release`;
  - `lock_expired` — the lease expired, the token is not renewed. Lease
    expiry does not trigger an automatic takeover: `task.lock.recover` is
    performed only by an explicit call after the recovery grace. If recovery
    is not performed, the expired lock record remains until a subsequent
    explicit recovery;
  - `stale_lock` — the token is no longer valid: the lock may have been
    released or taken over by recovery. The old owner does not perform further
    operations with this token.
- Prohibition: a repeated `task.lock.release` is not idempotent — it returns
  `stale_lock` (the lock is not held by this token). A repeat is performed
  only after a successful heartbeat confirming ownership.

### S4. Failure during locking (the lease expired during sub-agent execution)

- Fact: the lease expired, the Orchestrator was interrupted.
- Action: after lease expiry and the recovery grace (60 s), the Orchestrator
  calls `task.lock.recover`, obtaining a new token and an increased fencing
  generation. The recover is atomic: it runs in an Exclusive transaction with
  a CAS on `fencing_generation`, so competing recovers are serialized — only
  the first succeeds, the subsequent one gets `task_locked` (the fresh expiry
  is already in the future). The old token is invalid on any operation
  (`stale_lock`) after the recover. Before continuing, the Orchestrator
  verifies the current task version and the state of the artifacts.
- Prohibition: do not continue working with the old token after recovery.

### S5. Failure during cancellation

Cancellation sequence: `task.cancel` (outcome `cancelled`) → standard OpenSpec
archive (delta specs are not merged) → `task.lock.release`.

- Fact: one of the operations is performed, the other is not (for example,
  `task.cancel` is performed but the archive is not; or the archive is
  performed but the lock is not released).
- Action: reconcile the facts.
  - If the outcome `cancelled` is set — do not repeat `task.cancel` (a repeat
    → `task_terminal`); perform the OpenSpec archive (without merging the
    delta specs), then `task.lock.release`.
  - If the archive is performed but the outcome is not set — perform
    `task.cancel`, then `task.lock.release`.
  - If the outcome `cancelled` and the archive are performed but the lock is
    not released — verify ownership through `task.lock.heartbeat` (success →
    `release`; `stale_lock` → the token is no longer valid: the lock may have
    been released or taken over by recovery, the old owner does not perform
    further operations with this token; `lock_expired` → an explicit recovery
    after the grace if needed).
- Prohibition: do not merge the delta specs into permanent specs on
  cancellation; do not repeat `task.cancel` after the outcome is set.

## Operation idempotency

| Operation | Repeat |
|---|---|
| `task.status.set` to the same status (task not terminal) | no-op |
| `task.status.set` to any status after an outcome is set | `task_terminal` |
| `task.review.add` with the same `review_id` and payload | no-op |
| `task.commit.finalize` with the same SHA | no-op |
| `task.lock.release` without an active lock of this token | `stale_lock` (not an idempotent success); a repeat only after ownership is confirmed by a heartbeat |
| `task.complete` after an outcome is set | `task_terminal` |
| `task.cancel` after `cancelled` | `task_terminal` |

## Prohibitions

- Do not repeat `store.init` over an existing store.
- Do not perform `store.migrate` without a dry-run and user confirmation.
- Do not start the integration implementation until the change is separately
  approved.
- Do not modify Todoing, Manifest governance documents, or permanent specs
  within the scope of this change.