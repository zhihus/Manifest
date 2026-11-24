# Design

## Context

Manifest is a head/meta project of type `doc`. There is no program
orchestrator in the repository: orchestration is performed by the main agent
session (Main Orchestrator) executing the existing OpenSpec pipeline. Todoing
is a standalone universal tool; it does not know about Manifest, OpenSpec, or
roles. Manifest consumes only the public JSON API v1 through the CLI
`todoing api --json`: one JSON request via stdin, one JSON response via
stdout, diagnostics on stderr.

Target contract: `docs/architecture/todoing-contract.ru.md`. The Todoing API
v1 extensions (external references, Review history, revision_count, final
commit marker) are implemented and confirmed by audit at HEAD `d4c916e`.

## Decisions

### D1. Main Orchestrator — the sole client of the Todoing API

The Main Orchestrator (the main session) is the only participant that calls
the Todoing API and holds the lock token. Role sub-agents (Analyst,
Architect, Planner, Tester, Implementer, Reviewer) do not receive a lock
token and do not call Todoing directly. The Orchestrator passes the sub-agent
only artifacts and the task, and performs all Todoing operations itself.

Rationale: the lock token is a secret; distributing it to sub-agents creates
a leak risk and violates the invariant "nobody checks their own work". A
single client simplifies custody and recovery.

### D2. One Todoing task = one OpenSpec change

Each OpenSpec change (directory `openspec/changes/<id>/`) corresponds to
exactly one Todoing task. FR tasks within the change are a decomposition;
they are not created as separate Todoing tasks. The link is recorded as an
external reference: namespace `openspec.change`, value — the change directory
ID, relation `implements`, scope `project`. At most one active reference of
this namespace is allowed per task; one change ID is bound to at most one
task.

### D3. Project Identity — UUIDv4 in `.manifest/project-id`

The Project ID is a stable string that Todoing validates as 1–128 characters
without whitespace or control characters. For `.manifest/project-id`, UUIDv4
(RFC 4122) is used: 122 bits of entropy, resistance to collisions without
coordination, passes Todoing validation. The Todoing CLI itself generates
`p-<hex>` (128 bits) when `--project-id` is absent, so UUIDv4 is comparable
in entropy. Generation, validation, absence handling, and protection against
change are in `design/lifecycle.md` §Project identity and in the
`todoing-project-identity` spec.

### D4. Lock custody accounting for the blocking sub-agent

The Orchestrator is blocked while a role sub-agent runs and cannot maintain a
heartbeat during that period. Therefore the lease is configured to cover the
sub-agent's hard execution timeout (600 s per the watchdog in `AGENTS.md`)
with a buffer: lease 720 s = 600 + 120. The Orchestrator heartbeats only when
it is itself active (between sub-agent launches, at gates). Recovery is an
explicit `task.lock.recover` after lease expiry and grace; there is no
implicit takeover. Details in `design/lifecycle.md` §Lock custody.

### D5. Bootstrap without overwrite

Todoing installation is performed by the user; Manifest does not download or
update the binary. `store.init` creates a new store only when the database
does not exist; an existing `config.toml` is validated and preserved; legacy
Markdown tasks and `index.json` are rejected (`store.migrate` is required).
Manifest does not call `store.init` over an existing store or legacy data.
Automatic migration is not in the MVP. Details in `design/bootstrap.md`.

### D6. Completion and cancellation

Successful completion: Review approved → acceptance checks → standard
OpenSpec archive → Git merge per Manifest policy → `task.commit.finalize`
with the final merge SHA → `task.complete` → lock release. The Final Commit
SHA is a traceability marker, not proof of acceptance. Cancellation is
confirmed only by the user; upon confirmation the Orchestrator sets the
outcome `cancelled` through `task.cancel` and archives the OpenSpec change
through the standard mechanism; delta specs are not merged into permanent
specs. Details in `design/lifecycle.md` §Completion and `design/recovery.md`.

### D7. No cross-system transaction

Todoing, OpenSpec, and Git do not form a transaction. Each change is a
verifiable step with an idempotent retry or an explicit recovery. Blind
retries of non-idempotent operations are forbidden. Recovery reconciles the
actual states before repeating operations. Details in `design/recovery.md`.

## Open questions and external blockers

- **Schema parity (external blocker, Todoing):** the implementation returns
  the codes `store_already_initialized` (exit 6) and `migration_required`
  (exit 2), but `docs/api/v1/response.schema.json` does not include them in
  the enum. This does not block the Manifest-side design, but it blocks
  validating the integration against the schema until it is fixed in Todoing.
  Recorded as a prerequisite of the integration.
- **Todoing installation point:** the bootstrap is not tied to
  `scripts/manifest-init.sh` until it is confirmed that this is the standard
  installation point for users, not dev infrastructure.
- **Heartbeat during the sub-agent:** not guaranteed by the orchestration
  runtime capabilities; model D4 accounts for this through a lease that
  covers the hard timeout.