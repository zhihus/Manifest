# Todoing Contract for Manifest

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-23**  

# Description
Target integration specification for Manifest consuming Todoing JSON API v1.

**Baseline:** Todoing `zhihus/todoing-x` main @
`947048d3864e99c7d0dfcc48889a084e0a99e42d`; Manifest
`feature/todoing-contract-spec`.

> This edition replaces the previous CLI + file-WAL target model. It defines the
> target use of Todoing JSON API v1 and includes requirements for universal Todoing
> extensions needed to preserve previously approved Manifest decisions. Historical
> editions v2–v6 remain in separate Git files.
>
> **Implementation status:** base API capabilities were confirmed by the audit.
> External references, review records, and a final-commit marker are required
> universal Todoing extensions and are not yet implemented.

## 1. Architecture principle and responsibility boundaries

Todoing is an independent, universal task-management tool. Manifest is one of its
consumers. Todoing does not depend on Manifest and contains no knowledge of
Manifest, OpenSpec, agent roles, or project policy.

### 1.1. Todoing provides

- A separate SQLite task store for each project.
- Configurable statuses and permitted transitions.
- Task creation, reading, updating, completion, cancellation, archiving, and restore.
- Task dependencies with cycle prevention.
- Immutable versions and append-only operation history.
- An approved-version baseline.
- Exclusive locks with leases, heartbeat, recovery, and fencing generations.
- Git commit references stored as full SHAs.
- Versioned CLI and JSON API v1.
- Store verification, migration, and verified snapshots.
- Generic external references and structured review history, after the required API
  extensions are implemented.

### 1.2. Manifest provides

- Stable Project ID, project-store selection, and initialization.
- Orchestration, roles, sequencing, and agent assignment.
- User approvals and project-completion policy.
- OpenSpec workflow and interpretation of generic external references as OpenSpec
  change links.
- Git branch, review, and merge policy.
- Review workflow and Reviewer authority.
- Consistency across Todoing, OpenSpec, and Git.
- Actor authentication and secure custody of lock tokens.
- Backup destination, location, and retention policy.

Todoing does not parse OpenSpec or enforce Git workflow. It stores only generic
external references and commit references. It does not authenticate actors or
enforce consumer role policy.

## 2. API version and transport

### 2.1. Normative interface

Manifest uses only the public JSON API v1 through the `todoing api` CLI command.
Each call is a separate process: one JSON request on stdin and one JSON response
on stdout. Diagnostics go to stderr.

Required request-envelope fields are `api_version=1`, `project_id`, `actor_id`,
`operation`, and `args`. Optional fields are `request_id` and `lock_token`.
Unknown fields, unsupported operations, and unsupported API versions are rejected.
Errors are returned in a JSON envelope with a non-zero process exit code.

### 2.2. Identity and security

- Manifest assigns a stable Project ID and passes it in every request.
- Todoing checks the Project ID against store metadata. This prevents accidental
  access to the wrong store; it is not authentication.
- `actor_id` is history attribution, not proof of identity. Manifest creates actor
  IDs according to its own trust model.
- A lock token is a secret. It MUST NOT appear in task bodies, labels, logs,
  command-line arguments, or Git. Manifest keeps it only in protected session state
  and passes it in the request envelope as `lock_token`.
- Manifest MUST NOT read or modify SQLite directly.

### 2.3. Compatibility

Manifest relies on API v1 and its normative schemas and operation definitions.
It MUST NOT probe support by sending a mutating request. Before use, the integration
checks that the binary is available and that its version is compatible. Runtime
capabilities discovery is absent from Todoing and is not required for MVP.

### 2.4. Required universal API v1 extensions

The current Todoing API v1 implementation does not provide all previously approved
capabilities. Before Manifest integration, Todoing MUST extend the API and SQLite
schema with the following universal mechanisms. They MUST NOT contain
Manifest-specific or OpenSpec-specific fields or rules.

**External references**

- `task.external-ref.add`: accepts `task_id`, `namespace`, `value`, `relation`,
  and `scope` (`task` or `project`; default `task`). String fields are required,
  non-empty, and bounded.
- `task.external-ref.list`: accepts `task_id` and returns the task's active references.
- `task.external-ref.remove`: accepts `task_id` and `reference_id`.
  It removes an active link through an append-only event,
  preserving history and versions.
- With scope `task`, a `namespace + value` pair is unique within one task. With
  scope `project`, the pair is unique across the project store and conflicts with
  any other active reference using that pair. Todoing does not interpret namespace
  or relation; it only enforces the requested scope.
- Add/remove requires the owner's lock and creates a task version and history
  event; adding an identical active reference is a no-op.
- Re-adding the same active reference on the same task is a no-op; changing the
  relation for the same namespace/value pair is a conflict.
- Repeating removal of an inactive reference is a no-op; an unknown reference_id
  returns external_ref_not_found.
- Reference-list reads obey lock read-exclusion; a non-owner cannot read data from
  a locked task.
- External references are included in task responses and immutable version snapshots.

**Review records**

- `task.review.add`: accepts `task_id`, `review_id`, `version_no`, `reviewer`,
  `outcome` (`approved` or `changes_requested`), and a `comments` array.
  Envelope `actor_id` records the technical actor; `reviewer` is the reviewer's
  role or display name.
- `task.review.list`: accepts `task_id`, optional `before_review_record_id`, and
  `limit`; returns append-only review history with pagination.
- Repeating a `review_id` with the same payload is idempotent. Reusing it with a
  different payload is rejected.
- A review references an existing immutable task version. Adding a review does not
  change workflow status. Review creation and listing obey lock ownership; a
  non-owner cannot read Review data from a locked task.
- Each new review record, revision_count update, task version, history event, and
  snapshot MUST be committed atomically. An idempotent repeat MUST NOT create
  another version.
- `revision_count` is stored in task state and returned in the task response. It
  increases by exactly one for each new `changes_requested` record. Multiple
  comments in one record do not increase it. The counter, Review record, task
  version, and history event are committed atomically.

**Final commit reference**

- `task.commit.finalize` accepts `task_id` and `revision`, resolves the Git
  revision to a full SHA, and sets or updates the single current final commit reference.
- The operation requires the current owner's active lock and creates an immutable
  version and append-only history event. Repeating the same SHA is a no-op. A new
  SHA may replace the previous marker only for an active (reopened) task; the old
  value remains in prior immutable versions and history.
- Ordinary commit references remain separate traceability references.

## 3. Task and status model

### 3.1. Source of truth

Todoing is the single source of truth for a task's current workflow status and
outcome. Manifest MUST NOT keep a second copy or maintain a parallel status map.
Manifest may keep its own orchestration stages and review metadata, but these do
not replace Todoing status.

### 3.2. Recommended Manifest configuration

Manifest supplies a recommended `.todoing/config.toml`. Before `store.init`, it
creates `.todoing/` and atomically creates the config only if the file does not
exist. An existing file is never overwritten: Manifest validates it and stops
initialization with diagnostics if it is incompatible. Todoing `store.init`
validates and preserves an existing `config.toml`.

| ID | Display name | Purpose |
|---|---|---|
| `backlog` | Backlog | Discussion and task refinement |
| `ready` | Ready | User approved the task |
| `in_progress` | In progress | Agent is executing the task |
| `review` | In review | Result submitted to Reviewer |
| `verified` | Verified | Reviewer approved the result |
| `completed` | Completed | Orchestrator passed final checks |

Proposed transitions: `backlog → ready → in_progress → review`; from `review`,
either to `verified` on Reviewer approval or back to `in_progress` when changes
are requested; from `verified` to `completed` after final checks. Other
transitions are forbidden, except an explicitly permitted reopen operation for a
terminal outcome. Todoing enforces the configured graph; integration tests verify it.

API v1 has no operation for editing `config.toml`. The recommended configuration
is a project file. Manifest MUST install it through a separate controlled operation
and MUST NOT modify SQLite directly. The installation mechanism and protection of
user changes are detailed in Manifest implementation design.


Recommended Todoing configuration fragment:

```toml
format_version = 1

[locking]
lease_seconds = 300
heartbeat_seconds = 60
recovery_grace_seconds = 60

[[statuses]]
id = "backlog"
label = "Backlog"
enabled = true

[[statuses]]
id = "ready"
label = "Ready"
enabled = true

[[statuses]]
id = "in_progress"
label = "In Progress"
enabled = true

[[statuses]]
id = "review"
label = "In Review"
enabled = true

[[statuses]]
id = "verified"
label = "Verified"
enabled = true

[[statuses]]
id = "completed"
label = "Completed"
enabled = true
outcome = "completed"

[[transitions]]
from = "backlog"
to = "ready"

[[transitions]]
from = "ready"
to = "in_progress"

[[transitions]]
from = "in_progress"
to = "review"

[[transitions]]
from = "review"
to = "verified"

[[transitions]]
from = "review"
to = "in_progress"

[[transitions]]
from = "verified"
to = "completed"

[[transitions]]
from = "completed"
to = "verified"
```

The `completed → verified` transition is permitted only through `task.reopen`,
not ordinary status changes. If a user-provided config.toml already exists,
Manifest never replaces it; it checks for the required IDs, outcome mapping, and
transitions. An incompatible configuration blocks integration until explicitly
resolved.

The status-to-outcome mapping is explicit in Todoing configuration; Todoing MUST
NOT infer it from a status ID or display label. Manifest proposes mapping
`completed` to outcome `completed`. A terminal outcome requires explicit reopen
before further task changes. Cancellation uses `task.cancel` and does not require
a separate workflow status.

### 3.3. Status, outcome, and archive are separate dimensions

- Workflow status describes the work stage.
- Outcome describes completion or cancellation: `active`, `completed`, or
  `cancelled`.
- Archive state removes a task from the active list without changing status or
  outcome.

Manifest MUST NOT treat archive as cancellation and MUST NOT physically delete
tasks. After user approval, cancellation is recorded through `task.cancel` with
a reason. Todoing retains the workflow status and sets outcome `cancelled`.
Manifest archives the linked OpenSpec change through the standard OpenSpec Archive
mechanism. Base OpenSpec specifications remain unchanged.

## 4. Operational workflows

### 4.1. Project initialization

1. Manifest determines and stores a stable Project ID.
2. Manifest calls `store.init` with that ID.
3. Manifest verifies the result through `store.info` and `store.verify`.
4. Manifest atomically installs the recommended config only when the file is absent;
   `store.init` then validates and preserves it.
5. If legacy Markdown data exists, Manifest MUST NOT run `store.init` over it.
   Migration is a separate `store.migrate` procedure after reviewing its report.

### 4.2. Task creation and approval

- Analyst prepares a Backlog task together with the user.
- Manifest checks for duplicates and dependencies; Todoing creates the task through
  `task.create` with status `backlog`.
- The user approves the content and moves the task to `ready`. An agent MUST NOT
  treat a task as approved by itself.
- After explicit user approval, Manifest may set a baseline through
  `task.version.approve` for a specific existing version. Todoing does not
  authenticate the user; Manifest calls approve only after confirmed user action.

### 4.3. Execution and locking

1. The orchestrator selects an approved task.
2. The agent acquires a lock through `task.lock.acquire`.
3. Manifest keeps owner ID, token, and fencing generation in protected session
   state and passes the token with every owner request.
4. The agent renews the lease through `task.lock.heartbeat` while work continues.
5. Manifest moves the task to `in_progress` and performs permitted operations.
6. The agent releases the lock through `task.lock.release` when finished.

A task under lock is inaccessible to other clients for both reading and writing.
Todoing lists do not reveal even the IDs of locked tasks. Manifest MUST NOT bypass
this restriction by reading the database or using a snapshot.

### 4.4. Review and return

- Before submission, Manifest moves the task to `review` and provides the Reviewer
  with artifacts through its own workflow.
- The Reviewer independently checks the result.
- Manifest calls `task.review.add` with review_id, the reviewed version number,
  reviewer label, outcome, and ordered comments. Envelope actor_id identifies the
  Reviewer agent.
- On approval, Todoing stores a structured Review record with outcome `approved`;
  Manifest moves the task to `verified`.
- When changes are requested, Todoing atomically stores a Review record with
  outcome `changes_requested` and increments `revision_count` by exactly one;
  Manifest returns the task to `in_progress`.
- Repeating the same `review_id` with identical content is idempotent; the same ID
  with different content is rejected. A Review record references the exact immutable
  task version. Recording a Review does not change workflow status.
- Repeated review cycles do not require additional Todoing statuses.

`revision_count` is the number of Review records with outcome
`changes_requested`, not the number of task versions or comments. Todoing stores
Review history and `revision_count` as universal task data. Manifest determines
when a Reviewer may create a record and what workflow action follows its outcome.

### 4.5. Final completion

After status `verified`, the orchestrator runs final consistency checks across
Todoing, OpenSpec, and Git. On success, it moves the task to `completed`, which
maps to outcome `completed` if configured accordingly. A Git commit reference
alone does not prove completion.

### 4.6. Cancellation

1. Any agent may recommend cancellation with a reason.
2. Only the user approves cancellation.
3. After approval, Manifest calls `task.cancel` with the reason.
4. Manifest archives the linked OpenSpec change through the standard Archive
   mechanism.
5. Base OpenSpec specifications remain unchanged.

Cancellation MUST NOT be implemented only by changing workflow status or archiving
the task. The outcome and OpenSpec archive are separate actions. Reopening a
cancelled task requires an explicit decision and `task.reopen`.

## 5. Versions, history, and Git

- Every successful task-state save in Todoing creates an immutable version and an
  operation-history record in the same transaction. A no-op creates no new version.
- Manifest uses `task.history.list`, `task.version.list`, `task.version.get`,
  and `task.version.compare` for audit and comparison.
- `task.version.approve` sets the baseline to an existing version and creates no
  new version.
- Each significant change is linked through `task.commit.add`; Todoing resolves the
  revision to a full SHA. The final merge commit is set separately through
  `task.commit.finalize`. Neither reference proves that acceptance criteria passed.
- Branch, review, merge, and final-commit policy belong to Manifest.
- OpenSpec change IDs and other external identifiers MUST NOT be stored as Git
  commit references. Manifest links them through Todoing's generic external-reference
  API using namespace `openspec.change`, value equal to the change directory ID, and
  relation `implements`. Manifest allows at most one active link in this namespace
  per task; one change ID links to at most one task. Cancellation retains the link
  for audit. Task snapshots preserve references and the final commit marker.

## 6. Dependencies

Manifest manages dependencies through `task.dependency.add`,
`task.dependency.remove`, and `task.dependency.list`. External artifact links and
Review records are stored in Todoing through the generic API extensions in §2.4.
Those operations are absent from the current implementation and MUST be added to
Todoing without Manifest-specific semantics.

- A dependency means that a task must not start until its prerequisite is complete
  according to Manifest policy.
- Todoing verifies task existence and rejects cycles, but does not decide when a
  dependency is complete for Manifest workflow.
- Manifest checks dependency outcome/status before starting a task.
- Todoing may redact data about a locked dependency; Manifest MUST NOT bypass this.

## 7. Errors and recovery

Manifest handles stable API v1 error codes by their machine values, not by message
text. The codes `external_ref_conflict`, `review_id_conflict`,
`review_version_not_found`, and `final_commit_conflict` belong to the target API
extension and are absent from the current implementation.

| Situation | Manifest behavior |
|---|---|
| `project_id_mismatch` | Stop project integration; do not reinitialize the store automatically |
| `task_not_found` | Record a broken reference and request investigation |
| `task_locked` | Do not read or mutate; transfer control to owner or wait |
| `lock_expired` / `stale_lock` | Stop owner operations; run explicit recovery |
| `invalid_status_transition` | Do not bypass the graph; inspect config and task state |
| `task_terminal` | Require an explicit reopen decision; do not retry mutation automatically |
| `task_archived` | Do not mutate until explicit restore |
| `dependency_cycle` | Reject dependency change and report the cycle |
| `external_ref_conflict` | Do not overwrite the active link; report namespace/value conflict |
| `external_ref_not_found` | Do not mutate the task; report unknown reference_id |
| `review_id_conflict` | Do not change Review history; require a new review_id |
| `review_version_not_found` | Reject Review when the reviewed version does not exist |

| `store_corrupt` / `history_record_failed` | Fail closed: stop mutations and escalate |
| `store_busy` | Retry only when `retryable=true`, under a bounded retry policy |
| `invalid_request` / `unsupported_api_version` | Integration error; change request/version |

After lease expiry, Todoing does not transfer ownership automatically. Manifest may
call `task.lock.recover` only when Todoing's recovery conditions are met. Recovery
creates a new token and increments the fencing generation; the previous owner is
invalidated. Manifest checks the current task version before resuming work.

## 8. Hooks, events, and cross-component consistency

Manifest does not depend on Todoing hooks/events. The Todoing SQLite backend does
not execute legacy Markdown hooks. A generic lifecycle event API is deferred and
has no promised delivery, retry, or ordering semantics.

Manifest performs all correctness-critical checks itself:

- Before an operation: validate preconditions and permissions.
- After an operation: verify Todoing's result and consistency with OpenSpec/Git.
- After a cross-component failure: detect partial completion and recover through
  a logged Manifest workflow.

Todoing operations and OpenSpec/Git changes do not share a transaction. Manifest
MUST treat them as a sequence of verifiable steps with idempotent retries or explicit
recovery. It MUST NOT claim cross-system atomicity.

## 9. Snapshots, backup, and migration

- Manifest calls `store.snapshot`; it does not copy the active SQLite file.
- Todoing rejects snapshots while any task lock is active. Manifest schedules them
  outside agent work sessions.
- Manifest owns snapshot destination, retention, and replication policy.
- `store.verify` checks store integrity.
- `store.migrate` is a separate non-destructive procedure with a prior dry run
  and report review.
- Git is not a backup of the Todoing store.

## 10. MVP scope

### Included

1. One Todoing store per project with a stable Project ID.
2. JSON API v1 transport and compatibility checks.
3. Recommended configuration with six workflow statuses.
4. Task creation, status transitions, and complete/cancel outcomes.
5. Task locks, heartbeat, release, and explicit recovery.
6. Dependencies.
7. History, versions, version comparison, and user-approved baselines.
8. Git commit references and final commit marker.
9. Generic external references, Review history, and `revision_count` in Todoing;
   workflow policy remains in Manifest.
10. Manifest-side consistency checks and recovery from partial operations.
11. Store verification and on-demand snapshots.

### Excluded

- Manifest-specific fields or operations in Todoing. Required extensions must remain
  universal.
- Todoing capabilities-discovery API.
- Todoing lifecycle hooks/events as a correctness dependency.
- Arbitrary external links without a typed generic reference contract.
- Todoing GUI and multi-project dashboard.
- Remote backup, replication, and snapshot-retention implementation.
- Automatic status-configuration synchronization without explicit action.
- Automatic migration of legacy stores without dry run and approval.

## 11. Requirement coverage matrix

| Manifest requirement | Mechanism | Owner | Status |
|---|---|---|---|
| Tasks/statuses | task.create, task.status.set, config.toml | Todoing; policy — Manifest | Yes |
| Complete/cancel | task.complete, task.cancel, task.reopen | Todoing; approval — Manifest | Yes |
| History and versions | task.history.list, task.version.* | Todoing | Supported |
| Approval baseline | task.version.approve | Todoing; authorization — Manifest/user | Supported |
| Locks and fencing | task.lock.* | Todoing; token custody — Manifest | Supported |
| Dependencies | task.dependency.* | Todoing; execution gate — Manifest | Supported |
| Git refs/final marker | task.commit.add, task.commit.finalize | Todoing | Partial |
| OpenSpec link | Generic external refs | Todoing API; meaning — Manifest | Extension required |
| Review history | Generic review records | Todoing API; policy — Manifest | Extension required |
| revision_count | Count of changes_requested reviews | Todoing API | Extension required |
| Cross-system consistency | Consumer checks/workflow | Manifest | Manifest work required |
| Capabilities discovery | Not used in MVP | — | Deferred |
| Generic hooks/events | Not used for correctness | — | Deferred |

## 12. Integration acceptance scenarios

1. The store initializes with the expected Project ID; a request with another ID is
   rejected.
2. Analyst creates a Backlog task; user approval moves it to Ready.
3. The orchestrator cannot start an unapproved task.
4. An agent acquires a lock; another actor cannot read or mutate that task.
5. Heartbeat renews a lease; an expired lease cannot be renewed.
6. Recovery creates a new fencing generation; the former owner cannot continue.
7. Todoing rejects an invalid status transition; Manifest does not bypass it.
8. Reviewer `changes_requested` creates a Todoing Review record linked to the
   reviewed version and increments `revision_count` exactly once; task-version
   count is not used as the counter.
9. Reviewer approval moves the task to Verified; final checks move it to Completed.
10. Cancellation requires user approval, records outcome `cancelled`, and archives
    the linked OpenSpec change without changing base specifications.
11. A Git SHA is linked to a task but is not treated as proof of completion.
12. An OpenSpec change is linked to its Todoing task using namespace
    `openspec.change`; cancellation retains the link.
13. A failure between Todoing and OpenSpec/Git is detected and handled by recovery;
    no false cross-system atomicity is assumed.
14. Snapshot is rejected while a lock is active and passes verification after locks
    are released.
15. Critical errors are handled by error code; store/history corruption stops
    mutations.
16. A project-scoped namespace/value pair is unique within the store; a task-scoped
    pair is unique within one task. Removal preserves its history.
17. Repeating a review_id with the same payload creates no version and does not
    increment revision_count; a different payload is rejected.
18. Repeating the same final SHA is idempotent; replacement is allowed only after
    an explicit task reopen and creates a new version/history event.

## 13. Decisions required before approval

1. **Status configuration:** the proposed IDs, labels, and transition graph follow
   the six approved statuses in Architecture Brief §7. Manifest creates the config
   only when absent and never overwrites a user-provided file.
2. **Outcome mapping:** `completed` maps to outcome `completed`; cancellation is
   recorded as outcome `cancelled` without changing workflow status, consistent
   with Todoing's task-status-configuration specification.
3. **Universal Todoing API extensions:** approve external-reference and Review
   record schemas, final commit marker, `review_id` idempotency, and SQLite schema
   migration. These extensions MUST NOT contain Manifest/OpenSpec terminology or
   policy.
4. **Baseline approval:** Manifest calls `task.version.approve` after the user
   personally moves the task from Backlog to Ready; the baseline is the current
   task version.
5. **Project ID and actor ID:** the proposal is to generate a UUIDv4 Project ID
   once and store it in Manifest's stable configuration; actor_id is a stable
   role/session identifier of no more than 128 characters. The Project ID format
   requires confirmation. These values provide isolation/attribution, not
   authentication.

Until this document is approved, it remains a draft. Manifest integration
implementation starts after approval; universal Todoing extensions may be developed
as a separate task based on this specification.

## 14. Sources and limitations

Normative Todoing sources:

- `docs/api/v1/operations.md`
- `docs/api/v1/request.schema.json`
- `docs/api/v1/response.schema.json`
- `docs/integrations/consumer-contract.md`
- OpenSpec `task-cli` and related storage/API specifications

Manifest requirement sources:

- `architecture-brief.ru.md` §7–9
- `architecture-decisions.ru.md` §4–5
- `architecture-roadmap.ru.md` §1–3
- `todoing-implementation-audit.ru.md`

This specification was prepared against Todoing HEAD `947048d`. The full Todoing
test suite was not run during the audit. Before approval, an independent Reviewer
must compare every normative claim with the API schemas, implementation, and tests.
If Todoing changes API v1, this specification must be reviewed before integration
code changes.
