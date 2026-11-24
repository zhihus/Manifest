# Design — Task Lifecycle

## Project identity

The Project ID is a stable project identifier stored in
`.manifest/project-id` and passed in every Todoing API request.

- **Format:** UUIDv4 (RFC 4122). Passes Todoing validation (1–128 characters
  without whitespace or control characters). 122 bits of entropy — resistance
  to collisions without coordination.
- **Generation:** performed once during bootstrap, if the file is absent.
  Generation is an atomic write of a new UUIDv4 to `.manifest/project-id`.
- **Validation:** on every integration run Manifest reads
  `.manifest/project-id` and verifies that the value conforms to the Todoing
  Project ID rules. With an existing store, the value is reconciled with
  `store.info`; a mismatch → `project_id_mismatch` → stop.
- **Absent file:** when `.manifest/project-id` is absent and no store exists
  — bootstrap generates a new UUIDv4. When the file is absent but a store
  exists — stop: the ID is unknown, the store is not reinitialized.
- **Protection against accidental change:** the file `.manifest/project-id`
  is immutable after creation. Manifest does not overwrite it automatically.
  A change is possible only by an explicit user decision with store
  re-creation. On every integration run, reconciliation with `store.info`
  detects an unauthorized change.

## Lock custody

The Orchestrator is the sole holder of the lock token. The model accounts for
blocking role sub-agent execution.

- **Acquisition:** the Orchestrator calls `task.lock.acquire` for an approved
  task. It receives `owner_id`, `lock_token`, `fencing_generation`,
  `expires_at`. The token is stored only in the Orchestrator's protected
  session state and is passed in the envelope of every owner request.
- **Heartbeat:** the Orchestrator extends the lease through
  `task.lock.heartbeat` only when it is itself active — between sub-agent
  launches and at gates. During blocking sub-agent execution the Orchestrator
  is blocked and does not send a heartbeat.
- **Lease:** lease 720 s. Rationale: the sub-agent's hard execution timeout
  is 600 s (the watchdog in `AGENTS.md`); lease 720 = 600 + 120 s buffer. If
  the Orchestrator heartbeats immediately before launching the sub-agent, the
  lease survives the full 600-second sub-agent run.
- **Release:** when the task is finished, the Orchestrator calls
  `task.lock.release`.
- **Recovery:** when the lease expires (Orchestrator failure/interruption),
  Todoing does not transfer ownership automatically. After lease expiry and
  the recovery grace (60 s), the Orchestrator calls `task.lock.recover`,
  obtaining a new token and an increased fencing generation. The old owner
  becomes invalid. After recovery the Orchestrator verifies the current task
  version before continuing.

**It is not asserted** that a heartbeat every 60 s is guaranteed during
sub-agent execution — that is impossible in the current orchestration
runtime. The model ensures lease survival through a value that covers the
hard timeout.

## Task state

One OpenSpec change = one Todoing task.

- **Creation:** the user creates the task or the Analyst proposes it in the
  Backlog. Manifest creates the task through `task.create` with status
  `backlog` and records the external reference: namespace `openspec.change`,
  value — the change directory ID, relation `implements`, scope `project`.
- **Approval:** the `backlog → ready` transition is confirmed only by the
  user. An agent does not consider the task approved on its own. After
  approval, Manifest records the baseline through `task.version.approve` when
  needed.
- **Execution:** the Orchestrator acquires the lock, moves the task to
  `in_progress`, and runs the pipeline. Statuses: `backlog → ready →
  in_progress → review → verified → completed`; from `review` — to
  `verified` on approval or back to `in_progress` on remarks.
- **External reference:** at most one active reference of namespace
  `openspec.change` per task; one change ID is bound to at most one task. On
  cancellation the reference is preserved for audit.

## Review cycle

- **Handoff:** before handing off the result, the Orchestrator moves the task
  to `review` and passes the artifacts to the Reviewer through its own
  workflow.
- **Review record:** Manifest calls `task.review.add` with `review_id`,
  `version_no` of the reviewed version, `reviewer` label, `outcome`
  (`approved`/`changes_requested`), and an ordered `comments` array. The
  `actor_id` envelope records the Reviewer agent.
- **Approval:** Todoing stores the Review record with outcome `approved`;
  Manifest moves the task to `verified`.
- **Remarks:** Todoing atomically stores the record with outcome
  `changes_requested` and increases `revision_count` by exactly one; Manifest
  returns the task to `in_progress`.
- **Idempotency:** a repeated `review_id` with an identical payload is a
  no-op; the same ID with a different payload → `review_id_conflict`. A Review
  does not change the workflow status.

## Completion

Successful completion (a sequence of verifiable steps):

1. The `verified` status is reached (Review approved).
2. The Orchestrator runs the acceptance checks of Todoing ↔ OpenSpec ↔ Git
   consistency.
3. Standard OpenSpec archive: delta specs are merged into permanent specs,
   the change is moved to `openspec/changes/archive/`.
4. Git merge per Manifest policy (branches, review, merge).
5. `task.commit.finalize` with the final merge SHA — a traceability marker.
6. `task.status.set` → `completed` — the terminal transition. The `completed`
   status is mapped to outcome `completed` in `config.toml`, so the transition
   itself sets both `status_id = completed` and `outcome = completed`, making
   the task terminal.
7. Lock release through `task.lock.release`.

**Terminal-call semantics.** A transition to a status mapped to outcome
`completed` sets that outcome itself; a separate `task.complete` call is not
made in the success path. A repeated `task.complete` after such a transition
is rejected as `task_terminal` (the outcome is already set). `task.complete`
is an alternative terminal path that sets only the outcome without changing
the status; it is incompatible with a simultaneous transition to `completed`
and is not used in this model.

The Final Commit SHA is a traceability marker, not proof of successful
acceptance. The presence of a commit reference alone does not mean
completion.

## Cancellation

1. Any agent may recommend cancellation with a justification.
2. Only the user confirms the cancellation.
3. After confirmation, the Orchestrator calls `task.cancel` with a reason
   (outcome `cancelled`, the workflow status does not change). `task.cancel`
   sets a terminal outcome; a repeated call is rejected as `task_terminal`.
4. The Orchestrator archives the OpenSpec change through the standard Archive
   mechanism; delta specs are not merged into permanent specs.
5. The Orchestrator releases the lock through `task.lock.release`. The release
   is permitted after the terminal outcome is set: `task.lock.release` checks
   only the lock record (state, owner, token, expiry), not the task outcome.
   If the response to the release is lost — verify ownership through
   `task.lock.heartbeat` (success → repeat the release; `stale_lock` → the
   token is no longer valid: the lock may have been released or taken over by
   recovery, the old owner does not perform further operations with this
   token; `lock_expired` → an explicit recovery after the grace if needed).
6. The external reference is preserved for audit.

Cancellation is not performed by merely changing the status or archiving the
task: the outcome and the OpenSpec archive are recorded as separate actions.
Reopening a cancelled task requires an explicit decision and `task.reopen`.