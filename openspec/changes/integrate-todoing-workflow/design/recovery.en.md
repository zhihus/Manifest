# Design — Recovery After Partial Failure

## Principles

- Todoing, OpenSpec, and Git do not form a transaction. Each change is a
  verifiable step with an idempotent retry or an explicit recovery.
- **No blind retries of non-idempotent operations.** Before repeating an
  operation, the Orchestrator reconciles the actual state of the
  corresponding system.
- Recovery starts by reading the current state of all three systems (Todoing:
  status, outcome, lock, versions; OpenSpec: change presence/archival,
  permanent specs; Git: branch, merge, SHA) and only then deciding which
  operations are still pending.

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
| Complete | outcome `completed` | — | — |

## Recovery scenarios

### S1. Failure between OpenSpec archive and Git merge

- Fact: the change is already in `archive/`, permanent specs are updated, the
  merge is not performed.
- Action: do not repeat the archive (idempotent: the change is already
  archived). Perform the Git merge. After the merge — `task.commit.finalize`
  with the SHA, then `task.complete`.
- Verification: the merge commit SHA exists; `task.commit.finalize` is a
  no-op on a repeat with the same SHA.

### S2. Failure between Git merge and `task.commit.finalize`

- Fact: the merge is performed, the commit reference is not recorded.
- Action: obtain the merge commit SHA, perform `task.commit.finalize`. A
  repeat with the same SHA is a no-op. Then `task.complete`.

### S3. Failure between `task.complete` and lock release

- Fact: outcome `completed`, the lock is still active.
- Action: perform `task.lock.release`. A repeat is a no-op (the lock is
  already released → `task_terminal` or no active lock).

### S4. Failure during locking (the lease expired during sub-agent execution)

- Fact: the lease expired, the Orchestrator was interrupted.
- Action: after lease expiry and the recovery grace (60 s), the Orchestrator
  calls `task.lock.recover`, obtaining a new token and an increased fencing
  generation. The old token is invalid. Before continuing, the Orchestrator
  verifies the current task version and the state of the artifacts.
- Prohibition: do not continue working with the old token after recovery.

### S5. Failure during cancellation

- Fact: `task.cancel` is performed, the OpenSpec archive is not (or vice
  versa).
- Action: reconcile both facts. If the outcome is `cancelled` — perform the
  OpenSpec archive (without merging the delta specs). If the archive is
  performed but the outcome is not set — perform `task.cancel`.
- Prohibition: do not merge the delta specs into permanent specs on
  cancellation.

## Operation idempotency

| Operation | Repeat |
|---|---|
| `task.status.set` to the same status | no-op |
| `task.review.add` with the same `review_id` and payload | no-op |
| `task.commit.finalize` with the same SHA | no-op |
| `task.lock.release` without an active lock | error (do not repeat) |
| `task.complete` after `completed` | `task_terminal` |
| `task.cancel` after `cancelled` | `task_terminal` |

## Prohibitions

- Do not repeat `store.init` over an existing store.
- Do not perform `store.migrate` without a dry-run and user confirmation.
- Do not start the integration implementation until the change is separately
  approved.
- Do not modify Todoing, Manifest governance documents, or permanent specs
  within the scope of this change.