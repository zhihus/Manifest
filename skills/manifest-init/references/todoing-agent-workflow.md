# Todoing Agent Workflow

This reference defines stage 1: standalone Todoing task management. It does not
implement Todoing/OpenSpec coordination.

## Preconditions

Before using Todoing in a connected project:

1. Read `.manifest/manifest.yaml` and its checksum sidecar. Stop if the checksum,
   schema, or configuration is invalid.
2. Require `components.todoing.enabled: true`. If false, do not invoke Todoing.
3. Require `components.openspec.enabled: false` for this workflow. If OpenSpec is
   enabled, stop: cross-system Todoing/OpenSpec work belongs to the frozen next stage.
   Do not create OpenSpec references or archive changes.
4. Require the existing `.manifest/project-id`, `.todoing/config.toml`, and store.
   If bootstrap is incomplete, follow `todoing-bootstrap.md` only when the user
   explicitly asks to initialize Todoing. Never overwrite or migrate existing data.
5. Require a Todoing build from source commit
   `653788a954d2a120db1beba854308982814d8222` or a verified descendant.
   The current public `todoing-x/main` does not provide the external-reference,
   Review, and final-commit operations used by the full Manifest API workflow.
   Manifest does not install or update the binary.

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

1. Acquire the task lock with `task.lock.acquire`.
2. Immediately move `ready → in_progress` with `task.status.set`, supplying the
   token in the request envelope.
3. Keep `owner_id`, `lock_token`, `fencing_generation`, and expiry in protected
   Main Orchestrator session state.
4. Send `task.lock.heartbeat` immediately before each blocking role-agent run.
   Do not heartbeat while the role agent is running.
5. Never give the token to a role agent. Every owner operation must include the token
   in the envelope and the current owner ID/generation in its arguments.
6. On `stale_lock`, stop using the old token.

## Review and completion

1. After implementation, attach meaningful commits with `task.commit.add`.
2. Before independent review, move the task to `review`.
3. Record the review with `task.review.add`, linked to the exact reviewed
   `version_no`. Use a stable `review_id`, reviewer identity, outcome, and ordered
   comments.
4. On `approved`, move the task to `verified`.
5. On `changes_requested`, Todoing increments `revision_count` atomically; return
   the task to `in_progress` after recording the review.
6. After acceptance checks, set the final Git revision with
   `task.commit.finalize`, move the task to `completed`, then release the lock.
7. Do not run OpenSpec archive or create `openspec.change` references in this mode.

## Cancellation and recovery

- Only the user may approve cancellation. After approval, call `task.cancel` with a
  reason and release the lock. Do not run OpenSpec archive.
- After interruption, reconcile Todoing and Git before retrying operations:
  `task.get`, `task.version.list`, `task.history.list`, `task.review.list`,
  `task.dependency.list`, and Git branch/commit state.
- Never blindly repeat a non-idempotent operation.
- On `lock_expired`, wait for the lease plus recovery grace, then call
  `task.lock.recover`; use only the new token and fencing generation.
- On a lost release response, confirm ownership with `task.lock.heartbeat` before
  retrying release.
- Todoing and Git do not share a transaction. Stop and escalate if state is ambiguous.

## Trust boundary

`actor_id` is attribution, not authentication. The Main Orchestrator coordinates
Todoing operations under the agreed procedural authority boundary. Role agents
must not independently call Todoing or receive the lock token. This rule is
procedural; technical isolation is intentionally not implemented, and the runtime
does not block another process from invoking the API. Never claim that Todoing
authenticates actors or technically prevents direct calls.

This workflow does not modify project context files, enable context-file switches,
or implement Todoing/OpenSpec coordination.
