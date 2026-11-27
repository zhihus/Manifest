# Todoing Agent Workflow

This reference defines runtime Todoing task management in both standalone mode
and coordinated Todoing/OpenSpec mode.

## Preconditions

Before using Todoing in a connected project:

1. Read `.manifest/manifest.yaml` and its checksum sidecar. Stop if the checksum,
   schema, or configuration is invalid.
2. Require `components.todoing.enabled: true`. If false, do not invoke Todoing.
3. Read `components.openspec.enabled`. If false, use standalone Todoing mode.
   If true, use the coordinated registration rules below; do not stop merely
   because OpenSpec is enabled.
4. Require the existing `.manifest/project-id`, `.todoing/config.toml`, and store.
   If bootstrap is incomplete, follow `todoing-bootstrap.md` only when the user
   explicitly asks to initialize Todoing. Never overwrite or migrate existing data.
5. Require a Todoing build from source commit
   `653788a954d2a120db1beba854308982814d8222` or a verified descendant.
   The current public `todoing-x/main` does not provide the external-reference,
   Review, and final-commit operations used by the full Manifest API workflow.
   Manifest does not install or update the binary.

## Todoing/OpenSpec registration

Apply this section only when both `components.todoing.enabled: true` and
`components.openspec.enabled: true`.

1. Identify the exact OpenSpec change directory ID. Do not derive or invent an ID.
2. Inspect active Todoing tasks and their external references using
   `task.list` and `task.external-ref.list`. Reuse the task already linked to
   this change. If multiple tasks are linked, a title/reference disagrees, or
   the state is hidden or uncertain, stop and reconcile; never create a duplicate.
   In particular, if a task title matches the change ID but lacks the exact
   reference, or the exact reference belongs to a task with a different title,
   treat it as an ambiguous candidate and stop; do not create or repair a link
   automatically.
3. If no task is linked and absence is confirmed, create exactly one task with
   `task.create` in `backlog`. Its title MUST exactly equal the OpenSpec
   change directory ID. Keep the change goal, scope, and acceptance criteria
   in the task body.
4. Add exactly one project-scoped external reference with
   `task.external-ref.add`: namespace `openspec.change`, value equal to the
   exact change directory ID, relation `implements`, scope `project`.
   If creation succeeds but adding the reference fails, inspect actual state
   before retrying; reuse the created task and do not create another.
5. Keep all FR entries, checkboxes, implementation steps, and other work
   decomposition exclusively in that change's `tasks.md`. Never create
   separate Todoing tasks for FRs or checklist items.
6. The task MUST remain in `backlog` until the user explicitly authorizes
   execution. Discussion, analysis, drafting, or preparation is not approval.
7. Only after explicit user authorization, transition `backlog → ready`,
   read the resulting current task version with `task.get`, and record that
   exact version using `task.version.approve`. Complete the baseline approval
   before acquiring a lock, dispatching implementation, or moving to
   `in_progress`. If approval fails, do not start work.
8. A material change to the approved scope or acceptance criteria requires a
   new explicit user decision and a new baseline. Never infer approval from
   `actor_id`; it is attribution, not authentication.

When `components.openspec.enabled: false`, do not create an
`openspec.change` reference and do not invoke OpenSpec archive operations.

## API transport

Use only the public Todoing JSON API. Each call is a separate process:

```bash
printf '%s' '{"api_version":1,"project_id":"<PROJECT_ID>","actor_id":"manifest-orchestrator","operation":"task.list","args":{}}' | todoing --json api
```

- Send exactly one JSON request on stdin and read exactly one JSON response on stdout.
- Handle errors by the machine-readable `error.code`, not by message text.
- The envelope requires `api_version: 1`, `project_id`, `actor_id`, `operation`,
  and `args`.
- Never pass `lock_token` in CLI arguments, task content, labels, logs, or Git.
- Do not read or modify the SQLite database directly.

## Task discovery and granularity

1. At the start of a work session, call `task.list` and inspect relevant active tasks.
2. Reuse an existing task with the same intended outcome. Do not create duplicates.
3. If a potentially matching task is hidden by another owner's lock or its state
   cannot be verified, stop and resolve the uncertainty; do not assume it is absent.
4. Create one Todoing task per independently meaningful user-requested outcome.
   Implementation substeps, technical actions, and temporary checks stay inside the
   parent task; they are not separate Todoing tasks.
5. Do not add priority fields. The current Manifest task configuration does not use
   priorities.

## Create and update

- Create new tasks with `task.create` in `backlog`.
- Use a concise outcome as `title`; put the goal, boundaries, and acceptance
  criteria in `body`.
- A request to discuss, analyze, or prepare a plan is not approval to implement.
- An explicit user instruction to execute the work authorizes `backlog → ready`.
  After that approval:
  1. Call `task.status.set` to move the task to `ready`.
  2. Read the current version using `task.get`.
  3. Record that version with `task.version.approve`.
- Before changing an existing task, call `task.get`; update only supported fields
  `title` and `body` through `task.update`.
- A material change to scope or acceptance criteria after approval requires a new
  explicit user decision and a new approved baseline via `task.version.approve`.

## Dependencies

- Add and remove real prerequisite relationships with `task.dependency.add` and
  `task.dependency.remove`.
- Inspect them with `task.dependency.list` before dispatch.
- Every prerequisite must have outcome `completed`.
- If a prerequisite is incomplete, locked, or cannot be verified, do not start work.

## Execution and lock custody

The Main Orchestrator is the only Todoing API client and lock-token custodian.

1. Before execution, verify that the task is `ready`, its approved baseline is recorded, and every prerequisite has outcome `completed`.
2. Acquire the task lock with `task.lock.acquire`.
3. Immediately move `ready → in_progress` with `task.status.set`, supplying the token in the request envelope.
4. Keep `owner_id`, `lock_token`, `fencing_generation`, and expiry in protected Main Orchestrator session state. Never place the token in a prompt, environment, task content, logs, or Git.
5. Send `task.lock.heartbeat` immediately before each blocking role-agent run. Do not heartbeat while the role agent is running.
6. Every owner task request must include `lock_token` in the envelope. Supply `owner_id` and `fencing_generation` only for operations whose API contract requires them, namely `task.lock.heartbeat` and `task.lock.release`; do not add unsupported fields to other operation arguments. On `stale_lock`, stop using the old token.
7. Release the lock only after the task has reached its terminal outcome and all required cross-system operations have been reconciled.

## Independent review and revision loop

1. After implementation, attach meaningful commits with `task.commit.add`.
2. Before dispatching the independent Reviewer, move `in_progress → review` with `task.status.set`.
3. Give the Reviewer the exact artifacts and task version to inspect. The Reviewer must be a separate role/session from the Implementer and must not receive the lock token or call Todoing.
4. The Main Orchestrator records the result with `task.review.add`, including a stable `review_id`, exact reviewed `version_no`, reviewer identity, outcome, and ordered comments. The envelope `actor_id` identifies the Reviewer role/session.
5. On `approved`, call `task.status.set` to move `review → verified`. Do not mark the task completed yet.
6. On `changes_requested`, Todoing atomically appends the Review and increments `revision_count` exactly once. Then call `task.status.set` to move `review → in_progress` and return the findings to the Implementer. Preserve the Review record; never edit or delete it.
7. After corrections, attach the new meaningful commits and repeat the independent review cycle. `revision_count` counts `changes_requested` Review records, not task versions or comments. The same `review_id` and identical payload is idempotent; a different payload with that ID is a conflict.

## Completion

A task is eligible for completion only after status `verified` and successful acceptance checks.

For coordinated Todoing/OpenSpec work, perform these steps in order:

1. Verify the Review is approved and the task is `verified`.
2. Run final consistency checks across Todoing, the linked OpenSpec change, and Git.
3. Run `openspec archive <change-id> --yes` to merge delta specs into permanent specs and archive the change.
4. Merge Git according to the project's branch and commit rules.
5. Record the actual final merge SHA with `task.commit.finalize`.
6. Call `task.status.set` to move the task to `completed`; this records outcome `completed`.
7. Release the task lock with `task.lock.release`.

For standalone Todoing work, omit the OpenSpec archive step. After Review approval and acceptance checks:
1. Merge Git according to the project's rules when a merge is required.
2. Record the actual accepted final Git SHA with `task.commit.finalize`.
3. Call `task.status.set` to move the task to `completed`.
4. Call `task.lock.release`.
A Git commit reference alone never proves acceptance or completion.

## Cancellation

- Any agent may recommend cancellation with a reason; only the user may approve it.
- Without explicit user approval, do not call `task.cancel`, change the outcome, or archive the OpenSpec change.
- After approval, call `task.cancel` with the reason.
- In coordinated mode, then run `openspec archive <change-id> --yes --skip-specs`, retaining the external reference and leaving permanent specs unchanged.
- In standalone mode, do not invoke OpenSpec archive.
- Call `task.lock.release` after the cancellation and any required archive operation are reconciled. Archiving alone is not cancellation.

## Recovery

After interruption, reconcile actual state before retrying: Todoing through
`task.get`, `task.version.list`, `task.history.list`,
`task.review.list`, `task.external-ref.list`, and
`task.dependency.list`; OpenSpec change/archive state; and Git branch,
merge, and commit SHAs. Never blindly repeat a non-idempotent operation.

- If the `task.review.add` response was lost, inspect `task.review.list`.
  Treat the Review as already recorded only when the `review_id`, exact Review
  arguments, and envelope `actor_id` match. Do not append another record; reconcile
  task status and perform only the missing transition. If an existing record has
  a different `actor_id` or payload, stop and escalate. If no record exists, retry
  only after confirming the reviewed version and review ID are still valid.
- If the `task.lock.release` response was lost, call
  `task.lock.heartbeat` first. Retry release only if ownership is
  confirmed; otherwise reconcile whether release already succeeded and do not
  reuse the old token.
- On `lock_expired`, wait for lease expiry plus the configured recovery
  grace, then call `task.lock.recover`. Use only the new token and
  fencing generation; re-read the task version and inspect artifacts before
  continuing. On `stale_lock`, never use the old token again.
- **After OpenSpec archive but before Git merge:** verify the change is archived
  and permanent specs contain the delta; do not archive again. Continue with Git
  merge only after confirming the state.
- **After Git merge but before final commit marker:** obtain the actual merge SHA
  and call `task.commit.finalize`. Do not invent or infer the SHA.
- **After the final commit marker but before `completed`:** verify that the stored final SHA equals the actual merge SHA and that the task remains `verified`; do not replace the marker. After final acceptance checks, perform only the missing `task.status.set` transition.
- **After `completed` but before lock release:** verify terminal task state
  and confirm ownership before retrying release.
- **During cancellation:** reconcile task outcome, OpenSpec archive, and lock.
  If outcome is already `cancelled`, do not repeat `task.cancel`;
  perform only missing archive/release steps. Never merge delta specs for a
  cancelled change.
- **If a lease expires during a role-agent run:** recover only after the lease
  and grace period; use the new fencing generation and re-read the task version.
  Before dispatching another agent or mutating the shared worktree, confirm that
  the previous role-agent invocation has terminated. If termination cannot be
  confirmed, stop and escalate to the user; never allow overlapping writers.
  Inspect Git/OpenSpec artifacts before resuming. Do not assume the previous
  agent stopped or that its work was committed.

Todoing, OpenSpec, and Git do not share a transaction. Stop and escalate to the
user if the actual state is ambiguous or cannot be reconciled safely.

## Trust boundary

`actor_id` is attribution, not authentication. The Main Orchestrator coordinates
Todoing operations under the agreed procedural authority boundary. Role agents
must not independently call Todoing or receive the lock token. This rule is
procedural; technical isolation is intentionally not implemented, and the runtime
does not block another process from invoking the API. Never claim that Todoing
authenticates actors or technically prevents direct calls.

This workflow does not modify project context files or enable context-file switches.
