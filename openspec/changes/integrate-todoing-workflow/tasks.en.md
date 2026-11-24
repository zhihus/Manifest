# Tasks: integrate-todoing-workflow

> The integration implementation is performed by a separate decision after
> approval of this change. The tasks below are a decomposition for the
> subsequent implementation; they are not performed within this change.

## 1. Project Identity

- [ ] FR 1.1 Generate project-id file
  Generate a UUIDv4 and write it atomically to `.manifest/project-id` when
  the file is absent. Validate the value against Todoing Project ID rules
  (1–128 chars, no whitespace or control characters).
  Stop: file exists, contains a valid UUIDv4, and passes Todoing validation.
  Maps to scenarios: `todoing-project-identity` §Project ID generation.

- [ ] FR 1.2 Validate project-id on integration start
  Read `.manifest/project-id` on every integration start; validate the value
  and, when a store exists, reconcile it with `store.info`. On mismatch stop
  with `project_id_mismatch` diagnostics.
  Stop: validation logic covers present/absent file and present/absent store.
  Maps to scenarios: `todoing-project-identity` §Project ID validation.

- [ ] FR 1.3 Protect project-id from accidental change
  Ensure `.manifest/project-id` is never overwritten automatically after
  creation; change is possible only by explicit user decision with store
  re-creation.
  Stop: no automatic overwrite path exists in the bootstrap flow.
  Maps to scenarios: `todoing-project-identity` §Project ID protection.

## 2. Store Bootstrap

- [ ] FR 2.1 Check Todoing availability
  Verify the `todoing` binary is on PATH and `todoing api --json` responds.
  On unavailability stop with diagnostics; installation is performed by the
  user separately.
  Stop: availability check returns a clear stop or continue signal.
  Maps to scenarios: `todoing-store-bootstrap` §Todoing availability check.

- [ ] FR 2.2 Write config.toml without overwrite
  Create `.todoing/` and write the recommended `config.toml` atomically only
  when the file is absent. Validate an existing file for required statuses,
  outcome mapping, and transitions; on incompatibility stop bootstrap.
  Stop: existing config.toml is never overwritten; incompatible config stops
  bootstrap.
  Maps to scenarios: `todoing-store-bootstrap` §Configuration without overwrite.

- [ ] FR 2.3 Call store.init
  Call `store.init` with the Project ID from `.manifest/project-id`. The
  operation creates a new store only when the database does not exist.
  Stop: `store.init` is not called over an existing store or legacy data.
  Maps to scenarios: `todoing-store-bootstrap` §Store initialization.

- [ ] FR 2.4 Verify store
  Verify the result through `store.info` and `store.verify`.
  Stop: verification confirms the store is initialized and consistent.
  Maps to scenarios: `todoing-store-bootstrap` §Store verification.

## 3. Lock Custody

- [ ] FR 3.1 Acquire lock for approved task
  Orchestrator calls `task.lock.acquire` for an approved task, stores the
  token in protected session state, and passes it in every owner request
  envelope.
  Stop: token is stored and used in envelopes; role sub-agents do not receive
  it.
  Maps to scenarios: `todoing-lock-custody` §Lock acquisition.

- [ ] FR 3.2 Heartbeat when Orchestrator is active
  Orchestrator extends the lease through `task.lock.heartbeat` only when it
  is active (between sub-agent launches and at gates). No heartbeat is sent
  during blocking sub-agent execution.
  Stop: heartbeat is sent only when Orchestrator is active.
  Maps to scenarios: `todoing-lock-custody` §Heartbeat only when the Orchestrator is active.

- [ ] FR 3.3 Configure lease to cover hard timeout
  Configure lease to 720 s (600 s hard timeout + 120 s buffer) so the lease
  survives a full sub-agent run when the Orchestrator heartbeats immediately
  before launch.
  Stop: lease value is 720 s and justified in config.
  Maps to scenarios: `todoing-lock-custody` §Lease covers the hard timeout.

- [ ] FR 3.4 Release lock on completion
  Orchestrator calls `task.lock.release` when the task is finished.
  Stop: release is called after `task.complete`.
  Maps to scenarios: `todoing-lock-custody` §Lock release.

- [ ] FR 3.5 Recover lock after lease expiry
  After lease expiry and recovery grace (60 s), Orchestrator calls
  `task.lock.recover`, obtains a new token and increased fencing generation,
  and verifies the current task version before continuing.
  Stop: recovery is explicit; the old token is not used after recovery.
  Maps to scenarios: `todoing-lock-custody` §Recovery after lease expiry.

## 4. Task State and External Reference

- [ ] FR 4.1 Create task and external reference
  Create a Todoing task with status `backlog` and record the external
  reference: namespace `openspec.change`, value — change directory ID,
  relation `implements`, scope `project`.
  Stop: task exists with the external reference recorded.
  Maps to scenarios: `todoing-task-state` §Task and external reference creation.

- [ ] FR 4.2 Approve backlog-to-ready transition
  The `backlog → ready` transition is confirmed only by the user. After
  approval, Manifest records the baseline through `task.version.approve` when
  needed.
  Stop: the transition is not performed without user confirmation.
  Maps to scenarios: `todoing-task-state` §Approval of the backlog → ready transition.

- [ ] FR 4.3 Enforce external reference uniqueness
  Enforce at most one active `openspec.change` reference per task and at most
  one task per change ID. Preserve the reference on cancellation for audit.
  Stop: uniqueness constraints are enforced; the reference survives
  cancellation.
  Maps to scenarios: `todoing-task-state` §External reference uniqueness.

## 5. Review Cycle

- [ ] FR 5.1 Hand off to review
  Before handing off the result, Orchestrator moves the task to `review` and
  passes the artifacts to the Reviewer through its own workflow.
  Stop: the task is in `review` before the Reviewer starts.
  Maps to scenarios: `todoing-review-cycle` §Handoff to review.

- [ ] FR 5.2 Record review
  Manifest calls `task.review.add` with `review_id`, `version_no`, `reviewer`
  label, `outcome` (`approved`/`changes_requested`), and an ordered `comments`
  array. The `actor_id` envelope records the Reviewer agent.
  Stop: the review record is stored with the correct outcome and comments.
  Maps to scenarios: `todoing-review-cycle` §Review record.

- [ ] FR 5.3 Handle approval
  On `approved`, Todoing stores the review record and Manifest moves the task
  to `verified`.
  Stop: the task is in `verified` after an approved review.
  Maps to scenarios: `todoing-review-cycle` §Handling approval.

- [ ] FR 5.4 Handle changes requested
  On `changes_requested`, Todoing atomically stores the record and increases
  `revision_count` by exactly one; Manifest returns the task to `in_progress`.
  Stop: `revision_count` increases by one and the task is in `in_progress`.
  Maps to scenarios: `todoing-review-cycle` §Handling remarks.

## 6. Completion and Cancellation

- [ ] FR 6.1 Complete the task
  After `verified`, acceptance checks, OpenSpec archive, and Git merge, call
  `task.commit.finalize` with the final merge SHA, then `task.complete`, then
  `task.lock.release`.
  Stop: the task has outcome `completed`, the final commit SHA is recorded,
  and the lock is released.
  Maps to scenarios: `todoing-completion-recovery` §Successful completion.

- [ ] FR 6.2 Cancel the task
  After user confirmation, Orchestrator calls `task.cancel` with a reason
  (outcome `cancelled`) and archives the OpenSpec change through the standard
  mechanism; delta specs are not merged into permanent specs.
  Stop: the task has outcome `cancelled` and the change is archived without
  merging delta specs.
  Maps to scenarios: `todoing-completion-recovery` §Cancellation.

## 7. Recovery

- [ ] FR 7.1 Reconcile states before retry
  Before repeating any operation, Orchestrator reads the actual state of
  Todoing, OpenSpec, and Git and determines which operations are still
  pending.
  Stop: no operation is repeated without a state reconciliation step.
  Maps to scenarios: `todoing-completion-recovery` §Recovery after partial failure.

- [ ] FR 7.2 Handle partial-failure scenarios
  Implement recovery for the scenarios defined in `design/recovery.md`
  (S1–S5) with idempotent retries or explicit recovery.
  Stop: each scenario has a defined recovery path that does not repeat
  non-idempotent operations blindly.
  Maps to scenarios: `todoing-completion-recovery` §Recovery scenarios.