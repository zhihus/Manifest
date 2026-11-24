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
with the final merge SHA → `task.status.set` → `completed` (terminal
transition that sets outcome `completed`) → lock release. The Final Commit
SHA is a traceability marker, not proof of acceptance. Cancellation is
confirmed only by the user; upon confirmation the Orchestrator sets the
outcome `cancelled` through `task.cancel` (terminal outcome; a repeat →
`task_terminal`), archives the OpenSpec change through the standard mechanism
(delta specs are not merged), and releases the lock through
`task.lock.release`. Details in `design/lifecycle.md` §Completion and
`design/recovery.md`.

### D7. No cross-system transaction

Todoing, OpenSpec, and Git do not form a transaction. Each change is a
verifiable step with an idempotent retry or an explicit recovery. Blind
retries of non-idempotent operations are forbidden. Recovery reconciles the
actual states before repeating operations. Details in `design/recovery.md`.

### D8. RU/EN editions and validation scope

The OpenSpec CLI (v1.16.0) validates only the canonical change structure:
`proposal.md`, `design.md`, `tasks.md`, and the delta-specs in
`specs/<capability>/spec.md` (6 capabilities, RU). The validator ignores
top-level `.en.md` files and does not scan `specs-en/`.

- **Validated by OpenSpec:** `proposal.md`, `design.md`, `tasks.md`,
  `specs/<capability>/spec.md` (6 RU delta-specs).
- **Part of the change but outside OpenSpec validation:**
  `design/bootstrap.md`, `design/lifecycle.md`, `design/recovery.md` (RU
  design docs in the subfolder), all `.en.md` translations,
  `specs-en/<capability>/spec.md` (6 EN specs).

Rationale for `specs-en/`: the validator flags any file in a capability
folder containing `# Spec Delta` + `## ADDED Requirements` as a delta-spec; a
second such file in one folder breaks validation. The EN translations are
moved to a parallel `specs-en/` to avoid breaking validation. The workaround
is not eliminated because it does not cause a validation failure — it
prevents one.

RU/EN consistency: the RU edition is authoritative (the user reviews RU), the
EN edition is a faithful translation. Consistency is checked section by
section: the RU and EN section headers must match in structure, and the key
terms and Todoing API operations must match in meaning. The check is performed
manually on every RU-edition change (the EN is synchronized in the same
change) and at the final `openspec validate --strict` pass.

### D9. Implementation boundary

Manifest is a head/meta `doc` project; there is no program orchestrator or
tech stack in the repository. Orchestration is performed by the main agent
session (Main Orchestrator), executing the existing OpenSpec pipeline
(`workflow/README.ru.md`). The integration implementation is not a program but
a documented procedure that the Main Orchestrator performs by calling the
public Todoing JSON API v1 through the CLI `todoing api --json`.

Concrete implementation artifacts (where the integration is "implemented"):

- **Bootstrap files:** `.manifest/project-id` (UUIDv4, created once at
  bootstrap) and `.todoing/config.toml` (Todoing configuration: statuses,
  outcome mapping, transitions; created at bootstrap without overwrite).
- **Workflow documentation:** the integration procedure (bootstrap, lock
  custody, task state, review cycle, completion, recovery) is documented in
  `workflow/README.ru.md` (or a separate workflow document), which the Main
  Orchestrator executes as part of the OpenSpec pipeline.

The tasks in `tasks.md` are a decomposition for the subsequent implementation;
they are not performed within this change. Each task references a concrete
artifact (a bootstrap file or a workflow document) and describes what to add
to it.

## External blockers (Todoing) — do not block the integration

Both blockers require a separate Todoing doc/implementation sync task; neither
blocks the Manifest-side design or the integration implementation.

- **Schema parity (does not block the integration; requires a separate
  Todoing task):** the implementation returns the codes
  `store_already_initialized` (exit 6) and `migration_required` (exit 2), but
  `docs/api/v1/response.schema.json` does not include them in the enum. This
  blocks only validating the integration against the schema until it is fixed
  in Todoing; the Manifest-side design and implementation do not depend on the
  schema.
- **`task.lock.acquire` on an expired lock (does not block the integration;
  requires a separate Todoing task):** the documentation
  (`docs/api/v1/operations.md`, §task.lock.acquire) promises that an expired
  lock before the recovery grace returns `lock_expired`, and after the grace
  requires an explicit `task.lock.recover`. The implementation
  (`src/storage/lock.rs`, acquire) does not check `expires_at` and returns
  `task_locked` for any active lock, including expired ones. The Manifest does
  not depend on this: takeover of an expired lock is performed through
  `task.lock.recover`, not through `task.lock.acquire` (see
  `design/recovery.md` and the `todoing-lock-custody` spec).

## Open questions (Manifest-side)

- **Todoing installation point:** the bootstrap is not tied to
  `scripts/manifest-init.sh` until it is confirmed that this is the standard
  installation point for users, not dev infrastructure.
- **Heartbeat during the sub-agent:** not guaranteed by the orchestration
  runtime capabilities; model D4 accounts for this through a lease that
  covers the hard timeout.