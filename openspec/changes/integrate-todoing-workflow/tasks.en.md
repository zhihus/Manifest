# Tasks: integrate-todoing-workflow

> The integration implementation is performed by a separate decision after
> approval of this change. The tasks below are a decomposition for the
> subsequent implementation; they are not performed within this change.
>
> Architectural boundary (D9): Manifest is a head/meta `doc` project; there is
> no program orchestrator. The integration implementation is a documented
> procedure that the Main Orchestrator performs by calling the public Todoing
> JSON API v1 through the CLI `todoing api --json`. Implementation artifacts:
> bootstrap files (`.manifest/project-id`, `.todoing/config.toml`) and
> workflow documentation (`workflow/README.ru.md`). Details in `design.md` D9.

## 1. Project Identity

- [ ] fr-1.1-generate-project-id-file
  Create the file `.manifest/project-id`: when the file is absent, generate a
  UUIDv4 (RFC 4122) and write it atomically (write-to-temp + rename). Validate
  the value against Todoing Project ID rules: 1–128 characters, no whitespace
  or control characters. Format: one line, no trailing newline.
  Stop: the file exists, contains a valid UUIDv4 (8-4-4-4-12 hex), and passes
  Todoing Project ID validation.
  Maps to scenarios: `todoing-project-identity` §Project ID generation.

- [ ] fr-1.2-validate-project-id-on-start
  In `workflow/README.ru.md` (section «Bootstrap»), describe the procedure: on
  every integration start the Main Orchestrator reads `.manifest/project-id`,
  validates the value (UUIDv4, 1–128 characters, no whitespace), and, when a
  store exists, reconciles it with `store.info`. On mismatch — stop with
  `project_id_mismatch` diagnostics and a message to the user.
  Stop: the procedure is described in `workflow/README.ru.md` and covers the
  four combinations of present/absent file and present/absent store.
  Maps to scenarios: `todoing-project-identity` §Project ID validation.

- [ ] fr-1.3-protect-project-id-from-change
  In `workflow/README.ru.md` (section «Bootstrap»), fix the invariant:
  `.manifest/project-id` is never overwritten automatically after creation.
  Change is possible only by explicit user decision with store re-creation.
  The bootstrap procedure contains no code that overwrites an existing file.
  Stop: the described bootstrap procedure has no path for automatic
  overwrite of `.manifest/project-id`.
  Maps to scenarios: `todoing-project-identity` §Project ID protection.

## 2. Store Bootstrap

- [ ] fr-2.1-check-todoing-availability
  In `workflow/README.ru.md` (section «Bootstrap»), describe the check: the
  Main Orchestrator runs `todoing api --json` with a test request
  (`store.info`). If the binary is absent or does not respond — stop with
  diagnostics «Todoing not available; install manually». Installation is
  performed by the user separately.
  Stop: the described procedure has an explicit availability check and an
  explicit stop signal on unavailability.
  Maps to scenarios: `todoing-store-bootstrap` §Todoing availability check.

- [ ] fr-2.2-write-config-toml-without-overwrite
  Create the file `.todoing/config.toml` (when absent): six statuses
  (`backlog`, `ready`, `in_progress`, `review`, `verified`, `completed`),
  mapping `completed` → outcome `completed`, transitions per the model
  `backlog → ready → in_progress → review → verified → completed`.
  Locking section: `lease_seconds = 720`, `heartbeat_seconds = 60` (Todoing
  validation requires `heartbeat*3 < lease`, i.e. heartbeat < 240 s; 60 s
  passes). Atomic write (write-to-temp + rename) only when the file is absent.
  An existing file is validated: on incompatibility (missing status
  `completed` or wrong outcome mapping) — stop bootstrap.
  Stop: an existing `config.toml` is never overwritten; an incompatible
  config stops bootstrap.
  Maps to scenarios: `todoing-store-bootstrap` §Configuration without overwrite.

- [ ] fr-2.3-call-store-init
  In `workflow/README.ru.md` (section «Bootstrap»), describe the call to
  `store.init` with the Project ID from `.manifest/project-id`. The operation
  creates a new store only when the database does not exist. When a store
  exists — `store.init` is not called (protection against overwrite).
  Stop: in the described procedure `store.init` is not called over an existing
  store or legacy data.
  Maps to scenarios: `todoing-store-bootstrap` §Store initialization.

- [ ] fr-2.4-verify-store
  In `workflow/README.ru.md` (section «Bootstrap»), describe the
  verification: after `store.init` the Main Orchestrator calls `store.info`
  and `store.verify`. On mismatch — stop with diagnostics.
  Stop: the verification confirms that the store is initialized and
  consistent.
  Maps to scenarios: `todoing-store-bootstrap` §Store verification.

## 3. Lock Custody

- [ ] fr-3.1-acquire-lock-for-approved-task
  In `workflow/README.ru.md` (section «Lock custody»), describe: the Main
  Orchestrator calls `task.lock.acquire` for an approved task, receives
  `owner_id`, `lock_token`, `fencing_generation`, `expires_at`, and stores the
  token in its protected session state. The token is passed in the envelope of
  every owner request. Role sub-agents do not receive a lock token and do not
  call Todoing.
  Stop: in the described procedure the token is stored and used in envelopes;
  role sub-agents do not receive the token.
  Maps to scenarios: `todoing-lock-custody` §Lock acquisition.

- [ ] fr-3.2-heartbeat-when-orchestrator-active
  In `workflow/README.ru.md` (section «Lock custody»), describe: the Main
  Orchestrator extends the lease through `task.lock.heartbeat` only when it is
  itself active (between sub-agent launches, at gates). During blocking
  sub-agent execution no heartbeat is sent. The heartbeat is performed
  immediately before launching the sub-agent so that the lease covers its hard
  timeout.
  Stop: in the described procedure the heartbeat is sent only when the
  Orchestrator is active; the heartbeat is performed before the sub-agent
  launch, not during it.
  Maps to scenarios: `todoing-lock-custody` §Heartbeat only when the Orchestrator is active.

- [ ] fr-3.3-configure-lease-to-cover-hard-timeout
  In `workflow/README.ru.md` (section «Lock custody»), fix: lease = 720 s
  (600 s sub-agent hard timeout per the watchdog in `AGENTS.md` + 120 s
  buffer). The lease covers a full sub-agent run when the Orchestrator
  heartbeats immediately before launch.
  Stop: the lease value in the workflow document is 720 s and justified
  (600 + 120).
  Maps to scenarios: `todoing-lock-custody` §Lease covers the hard timeout.

- [ ] fr-3.4-release-lock-on-completion
  In `workflow/README.ru.md` (section «Completion»), describe: the Main
  Orchestrator calls `task.lock.release` after `task.status.set` → `completed`
  (terminal transition). A repeated `task.lock.release` returns `stale_lock`
  (not an idempotent success).
  Stop: in the described procedure the release is called after
  `task.status.set` → `completed`; a repeated release is not called.
  Maps to scenarios: `todoing-lock-custody` §Lock release.

- [ ] fr-3.5-recover-lock-after-lease-expiry
  In `workflow/README.ru.md` (section «Recovery»), describe: after lease
  expiry and the recovery grace (60 s) the Main Orchestrator calls
  `task.lock.recover`, obtaining a new token and an increased fencing
  generation. The old token becomes invalid (`stale_lock` on any operation).
  After recovery the Orchestrator verifies the current task version before
  continuing. Competing recovers are atomic: only the first succeeds
  (Exclusive transaction + CAS on `fencing_generation`); the second gets
  `task_locked`.
  Stop: recovery is described explicitly; the old token is not used after
  recovery; concurrency is accounted for.
  Maps to scenarios: `todoing-lock-custody` §Recovery after lease expiry.

## 4. Task State and External Reference

- [ ] fr-4.1-create-task-and-external-reference
  In `workflow/README.ru.md` (section «Task state»), describe: the Main
  Orchestrator creates a Todoing task with status `backlog` and records the
  external reference: namespace `openspec.change`, value — the change
  directory ID, relation `implements`, scope `project`.
  Stop: in the described procedure the task is created with the external
  reference.
  Maps to scenarios: `todoing-task-state` §Task and external reference creation.

- [ ] fr-4.2-approve-backlog-to-ready-transition
  In `workflow/README.ru.md` (section «Task state»), describe: the
  `backlog → ready` transition is confirmed only by the user. After approval
  Manifest records the baseline through `task.version.approve` when needed.
  Stop: in the described procedure the transition is not performed without
  user confirmation.
  Maps to scenarios: `todoing-task-state` §Approval of the backlog → ready transition.

- [ ] fr-4.3-enforce-external-reference-uniqueness
  In `workflow/README.ru.md` (section «Task state»), fix: at most one active
  `openspec.change` reference per task and at most one task per change ID. On
  cancellation the reference is preserved for audit.
  Stop: the uniqueness constraints are described; the reference survives
  cancellation.
  Maps to scenarios: `todoing-task-state` §External reference uniqueness.

## 5. Review Cycle

- [ ] fr-5.1-hand-off-to-review
  In `workflow/README.ru.md` (section «Review cycle»), describe: before
  handing off the result the Main Orchestrator moves the task to `review` and
  passes the artifacts to the Reviewer through its own workflow.
  Stop: in the described procedure the task is in `review` before the Reviewer
  starts.
  Maps to scenarios: `todoing-review-cycle` §Handoff to review.

- [ ] fr-5.2-record-review
  In `workflow/README.ru.md` (section «Review cycle»), describe: Manifest
  calls `task.review.add` with `review_id`, `version_no`, the `reviewer`
  label, `outcome` (`approved`/`changes_requested`), and an ordered `comments`
  array. The `actor_id` envelope records the Reviewer agent.
  Stop: the review record is stored with the correct outcome and comments.
  Maps to scenarios: `todoing-review-cycle` §Review record.

- [ ] fr-5.3-handle-approval
  In `workflow/README.ru.md` (section «Review cycle»), describe: on
  `approved` Todoing stores the review record and Manifest moves the task to
  `verified`.
  Stop: after an approved review the task is in `verified`.
  Maps to scenarios: `todoing-review-cycle` §Handling approval.

- [ ] fr-5.4-handle-changes-requested
  In `workflow/README.ru.md` (section «Review cycle»), describe: on
  `changes_requested` Todoing atomically stores the record and increases
  `revision_count` by exactly one; Manifest returns the task to
  `in_progress`.
  Stop: `revision_count` increases by one and the task is in `in_progress`.
  Maps to scenarios: `todoing-review-cycle` §Handling remarks.

## 6. Completion and Cancellation

- [ ] fr-6.1-complete-the-task
  In `workflow/README.ru.md` (section «Completion»), describe: after
  `verified`, acceptance checks, OpenSpec archive, and Git merge the Main
  Orchestrator calls `task.commit.finalize` with the final merge SHA, then
  `task.status.set` → `completed` (terminal transition that itself sets
  outcome `completed`), then `task.lock.release`. A separate `task.complete`
  call is not made in the success path; a repeated `task.complete` after
  `completed` is rejected as `task_terminal`.
  Stop: the task has status `completed` and outcome `completed`, the final
  commit SHA is recorded, and the lock is released.
  Maps to scenarios: `todoing-completion-recovery` §Successful completion.

- [ ] fr-6.2-cancel-the-task
  In `workflow/README.ru.md` (section «Completion»), describe: after user
  confirmation the Main Orchestrator calls `task.cancel` with a reason
  (outcome `cancelled`) and archives the OpenSpec change through the standard
  mechanism; delta specs are not merged into permanent specs. The external
  reference is preserved for audit.
  Stop: the task has outcome `cancelled`, the change is archived without
  merging delta specs, and the reference is preserved.
  Maps to scenarios: `todoing-completion-recovery` §Cancellation.

## 7. Recovery

- [ ] fr-7.1-reconcile-states-before-retry
  In `workflow/README.ru.md` (section «Recovery»), describe: before repeating
  any operation the Main Orchestrator reads the actual state of Todoing,
  OpenSpec, and Git and determines which operations are still pending. Blind
  retries of non-idempotent operations are forbidden.
  Stop: in the described procedure no operation is repeated without a state
  reconciliation step.
  Maps to scenarios: `todoing-completion-recovery` §Recovery after partial failure.

- [ ] fr-7.2-handle-partial-failure-scenarios
  In `workflow/README.ru.md` (section «Recovery»), describe recovery for the
  scenarios S1–S5 from `design/recovery.md`: (S1) between the OpenSpec archive
  and the Git merge; (S2) between the Git merge and `task.commit.finalize`;
  (S3) between the transition to `completed` and the lock release; (S4) lease
  expiry during the sub-agent; (S5) cancellation. Each scenario — an
  idempotent retry or an explicit recovery with a prior state reconciliation.
  Stop: each scenario S1–S5 has a described recovery path that does not
  repeat non-idempotent operations blindly.
  Maps to scenarios: `todoing-completion-recovery` §Recovery scenarios.