# OpenSpec Protocol

# Metadata
> **Status: active**  
> **Type: document**  
> **Version: 1.1.2**  
> **Updated: 2026-11-27**  

# Description
Process for working with LLM agents on the OpenSpec pipeline; task
rules live in `openspec-rules.md`.

Sequential execution is a Manifest rule: agents run one at a time,
no parallel dispatch (analysis, implementation, verification alike);
one global task per project at a time.

## 0. Workflow Configuration and Switches

Before starting work, the Orchestrator reads `.manifest/manifest.yaml` and
verifies its SHA-256 against `.manifest/manifest.yaml.checksum`. Integrity
verification is mandatory and is not controlled by switches. If the file is
missing, the checksum differs, the format version is unsupported, or a switch
has an invalid value, the Orchestrator stops and reports the exact key/reason.
Legacy configurations without `format_version` and switch sections are not
migrated automatically.

For `format_version: 1`, the following independent switches apply:

| Key | Default | Behavior |
|---|---:|---|
| `components.todoing.enabled` | `true` | Use Todoing API, tasks, history, and locks |
| `components.openspec.enabled` | `false` | Use OpenSpec changes and permanent specifications |
| `checks.workflow_preflight.enabled` | `false` | Run workflow Preflight |
| `checks.git_hooks.enabled` | `false` | Install/run Manifest Git hooks |
| `checks.git_checks.enabled` | `false` | Run additional Manifest Git checks |
| `checks.openspec_validation.enabled` | `false` | Run `openspec validate` |
| `checks.tests.enabled` | `false` | Run tests |
| `checks.review_gate.enabled` | `false` | Run the separate Review/verify gate |
| `checks.additional_gates.enabled` | `false` | Run other optional control mechanisms |

The Orchestrator checks the corresponding flag immediately before each stage.
When it is `false`, the stage, command, hook, or subagent is not launched;
the stage is recorded as `SKIPPED`, not `PASSED`. One switch never changes
the value of another.

If Todoing is enabled while OpenSpec is disabled, tasks are managed in Todoing
without a required OpenSpec reference. If OpenSpec is enabled while Todoing is
disabled, changes are managed in OpenSpec without Todoing calls. When both
components are enabled, one Todoing task corresponds to one OpenSpec change:
the Todoing task title MUST exactly equal the change directory ID, and the
`openspec.change` reference is mandatory.

The `workflow_preflight` switch controls only the workflow Preflight stage.
The mandatory safety checks performed by `manifest-init.sh` (Git work tree,
template availability, safe write access, and required tools) remain enabled.
Checksum protection and the prohibition on automatically rewriting an existing
configuration always remain active. Reconnection is additive: it adds only missing
items and preserves existing files and settings. These protections cannot be
disabled by configuration.

## 1. Roles

The pipeline exists inside the **Orchestrator** context (the main session /
conductor). It never performs a specialist's job: it restores pipeline state,
dispatches the right subagent at each step, checks the agent's report, and
gates the transition to the next step. This preserves the core invariant:
**no role ever checks its own work.**

| Step | Artifact | Agent | Input → Output |
|---|---|---|---|
| — | pipeline state | Orchestrator (always GLM-5.3 Flash) | runs steps, gates transitions |
| 0 | task in Todoing (when enabled) | Analyst | Backlog → approved task, "Ready" |
| 1 | proposal.md (when OpenSpec is enabled) | Analyst | user's words → "why / what" |
| 2 | spec.md (when OpenSpec is enabled) | Analyst | proposal → scenarios, edge cases, PBT |
| 3 | design.md (when OpenSpec is enabled) | Architect | proposal + spec → solution (optional) |
| 4 | tasks.md (when OpenSpec is enabled) | Planner | spec + design → atomic task checklist |
| 5.1 | tests (when checks.tests.enabled) | Tester | spec properties → tests before code |
| 5.2 | code or document | Implementer / Documenter | tasks + spec → implementation |
| 6 | verify.md (when checks.review_gate.enabled) | Reviewer | artifacts + spec → ✅/❌ report |
| 7 | archive (when OpenSpec is enabled) | Orchestrator | verify all ✅ → specs updated |

Each role runs in its own agent session (subagent run); the same model
may serve different roles, model-per-role assignment is not fixed. The
Orchestrator may combine roles across different changes but never within
one deliverable. Reviewer findings go back to the Orchestrator, which
re-runs the Implementer until findings are fully resolved; blocking
errors escalate to the user. The mandatory role list lives in
`docs/architecture/architecture-brief.ru.md` §9
(7 roles, incl. Tester and Analyst).

## 2. The Seven Steps and Gates

### 2.1. Proposal (Analyst)

Answers *why* and *what* changes, without behavior detail or technical
solutions. Sections: `Why`, `What Changes`, `Capabilities`.

**Gate:** `Why` present, `What Changes` non-empty, capability list
explicit. Fail → back to Analyst.

### 2.2. Spec (Analyst)

The behavioral contract: every proposal requirement expanded into user
stories, `GIVEN / WHEN / THEN` scenarios, edge cases, and — where
executable behavior is expected — **properties for property-based tests
(P1, P2, …)**. The spec, not the code, is the source of truth for the
Tester. If a behavior is not in the spec, it does not exist.

**Gate:** every requirement has ≥1 scenario; edge cases listed; PBT
properties derived (for code changes). Fail → back to Analyst.

### 2.3. Design (Architect)

Technical plan: data structures, algorithms, trade-offs. May not
contradict the spec; on conflict the spec is edited deliberately (by
the Analyst), never silently worked around. Optional for small
changes, mandatory when there is a choice between solutions.

**Gate:** design references the spec and introduces no requirements
absent from it. Fail → back to Analyst (revisit spec).

### 2.4. Tasks (Planner)

Atomic, individually verifiable tasks, each traceable to a scenario or
property. Follows `openspec-rules.md`: FR numbering, wave groups, size
calibration (one task = one executor run, < 10 minutes, mechanical
stop criterion), `Maps to scenarios:` line.

**Gate:** every task is a checkbox and traceable to a scenario/property;
wave structure valid. Fail → back to Planner.

### 2.5. Apply (Tester → Implementer / Documenter)

Two distinct roles, in that order. Launch the Tester only when `checks.tests.enabled: true`; when `false`, skip step 5.1 and the Tester with status `SKIPPED`. Implementation continues without running tests.

#### 2.5.1. The Tester writes tests before implementation

From `spec.md` only (properties P1–P3 …), never from code. This makes
tests check requirements, not chase the implementation.

#### 2.5.2. The Implementer writes the implementation against the tests

Input: `tasks.md` + `spec.md`. The Implementer never edits tests: a
failing test is a bug in the implementation. Properties change only
via a deliberate spec edit by the Analyst.

#### 2.5.3. The doc-only path

For documentation deliverables, step 5.1 is skipped (no executable
contract; the property "the document matches the spec" is checked by
reading). The Implementer role is performed by a **Documenter** — a
separate agent whose only job is to produce the document per
`spec.md` + `design.md`, marked `doc-only` in `tasks.md`. If a change
contains both code and docs, the Documenter runs as a separate
session like the other agents — sequentially; parallel dispatch is
forbidden. Review still happens (step 6) — a
semantic check: completeness, consistency, no requirements absent
from the spec.

**Gate:** for code — tests unmodified since the Tester wrote them; the
Implementer touched no test files. For doc-only — task marked
`doc-only`, artifact created, Documenter edited no spec files.
Fail → back to step 5.

### 2.6. Verify (Reviewer)

Run this stage only when `checks.review_gate.enabled: true`; otherwise skip the separate Review/verify gate and Reviewer with status `SKIPPED`.

A conformance check against the spec, not a style review. For each
scenario and property: covered by a test and passing on the
implementation (code), or the document matches scenarios and adds
nothing new (doc-only). Tests are not tautological; all `tasks.md`
items closed. The Reviewer edits nothing — it produces `verify.md`
(✅/❌) and routes failures: test gap → Tester, failing test →
Implementer, spec contradiction → Analyst, incomplete doc →
Documenter.

**Gate:** `verify.md` contains only ✅ → proceed to step 7. Any ❌ →
route back and re-run the affected step.

### 2.7. Archive (Orchestrator / automation)

Run this stage only when `components.openspec.enabled: true`; otherwise do not run OpenSpec archive.

Triggered only after verify is all ✅. The delta-spec from
`changes/<name>/specs/` merges into the permanent `openspec/specs/`,
the change folder moves to `changes/archive/<date>-<name>/`.
Mechanical, usually a CLI operation (`openspec archive <name>`). From
this point the requirement is standing law for all future changes.

## 3. Relation to openspec-rules.md

* Steps 1–4 = "strong model / human" work per the rules file.
* Step 4 output = waves, FR numbering, size calibration.
* Step 5 = executor runs: one subagent run = one task (FR); executor
  commits after each completed stage.
* Heavy verification is its own task (step 6 in its own run).
* Archive (step 7) matches `openspec/changes/archive/`.

## 4. Language

All artifacts (`proposal.md`, `spec.md`, `design.md`, `tasks.md`,
`verify.md`) and process context files are written in English, unless a
project's rules state otherwise. Scenario bodies inside specs may be in the
project's domain language when required by the runtime that consumes them
(e.g. Russian Gherkin for 1C/Vanessa), while the spec document itself stays
English.

## 5. Minimal Runbook (user's view)

1. State the change in plain words; confirm edge cases when asked.
2. The Orchestrator drives steps 1–7, dispatching one role per step
   and reporting gate results.
3. You intervene only when a gate fails to a point the Orchestrator
   routes back to you (scope questions, spec conflicts) or at the
   final verify ✅.


## 6. Todoing integration

This section applies only when `components.todoing.enabled: true`. When it is `false`, the Orchestrator does not invoke `todoing`, read `.todoing/`, or perform Todoing operations.

Todoing is the source of truth for task state, versions, history, locks, and Reviews. Manifest owns OpenSpec, Git, and orchestration policy. The main Orchestrator is the only Todoing API client.

### 6.1. Bootstrap and Project ID

Two usage modes are supported: a normal install on PATH, and a portable package referenced by an explicit path. The resolver scripts (`scripts/resolve-todoing.sh` / `scripts/resolve-todoing.py`) apply a strict priority and verify the version before any store operation:

1. Explicit `TODOING_BIN` — must point to an existing file; a missing file is a hard stop.
2. Portable build in the Manifest release cache: `.todoing-cache/portable/<VERSION>/<PLATFORM>-<ARCH>/todoing[.exe]`.
3. `todoing` found on PATH.

An incompatible version is a hard stop: the resolver never silently falls back to another binary. The release cache (`.todoing-cache/`) holds downloaded releases separated by version and platform, is never mixed with the user task store (`.todoing/`), and is git-ignored.

1. Verify that the resolver found a binary and that `todoing version` matches the required version (currently `1.2.0`), and that the binary is compatible with the baseline build below. Stop with a diagnostic if the binary is missing or incompatible. Manifest does not install or update Todoing. Invoke the JSON API as `todoing --json api`: send one JSON request on stdin and read one JSON response from stdout.

The full Manifest workflow requires a Todoing build from commit `653788a954d2a120db1beba854308982814d8222` or a verified descendant. Manifest's acceptance CI pins this commit. The current public `todoing-x/main` does not contain `task.external-ref.*`, `task.review.*`, or `task.commit.finalize`; a binary built from that branch is incompatible with the full workflow. `todoing version` confirms CLI availability but may not identify its source commit, so verify build provenance separately.
2. If both `.manifest/project-id` and the SQLite store are absent, generate a UUIDv4 and create the file atomically without overwriting an existing file.
3. If the store exists but the Project ID is missing, stop. Do not generate a replacement ID or call `store.init`.
4. If the Project ID exists, reuse it unchanged. For an existing store, call `store.info` and `store.verify`; an ID mismatch or integrity failure is a hard stop.
5. Inspect `.todoing/config.toml`. If the store already exists but the config is missing, stop; do not create a configuration with unknown policy over an existing store. If the store is absent, create the config only when there are no legacy Markdown tasks or `index.json`. Never overwrite an existing config; inspect it and stop if it is incompatible.
6. Recommended configuration: `format_version = 1`; statuses `backlog`, `ready`, `in_progress`, `review`, `verified`, `completed`; only `completed` maps to `outcome = "completed"`. Allowed transitions: `backlog → ready → in_progress → review`; from `review` to `in_progress` or `verified`; from `verified` to `completed`.
7. Set `[locking]` to `lease_seconds = 720`, `heartbeat_seconds = 60`, and `recovery_grace_seconds = 60`. These values are required for the lock protocol below.

Recommended `.todoing/config.toml` for a new project:

```toml
format_version = 1

[locking]
lease_seconds = 720
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
to = "in_progress"

[[transitions]]
from = "review"
to = "verified"

[[transitions]]
from = "verified"
to = "completed"
```

Create this file only when it does not exist. Never apply the snippet automatically over an existing configuration.
8. For a new project, call `store.init` exactly once with the Project ID. Then verify with `store.info` and `store.verify`. Never call `store.init` over an existing store. Do not migrate legacy data automatically: run a dry run and obtain separate user approval first.

### 6.2. API contract and task mapping

Each call is a separate `todoing api` process: one JSON request on stdin and one JSON response on stdout. The envelope contains `api_version: 1`, `project_id`, `actor_id`, `operation`, and `args`; `lock_token` is supplied only in the envelope of owner requests. Handle errors by machine-readable `code`, never by message text. Never put the token in CLI arguments, a subagent prompt, task content, logs, or Git.

Example: list tasks (replace the Project ID):

```bash
printf '%s' '{"api_version":1,"project_id":"<PROJECT_ID>","actor_id":"manifest-orchestrator","operation":"task.list","args":{}}' | todoing --json api
```

One OpenSpec change maps to one Todoing task. When both Todoing and OpenSpec are enabled, the Todoing task title MUST exactly equal the OpenSpec change directory ID; FR tasks inside a change are not separate Todoing tasks:
- Create the task with `task.create` and status `backlog`.
- Add a project-scoped reference with `task.external-ref.add`: namespace `openspec.change`, value equal to the change directory ID, relation `implements`, scope `project`.
- Allow `backlog → ready` only after explicit user approval. Then record the current version as the baseline with `task.version.approve`.
- Do not dispatch implementation, acquire a lock, or move the task to `in_progress` before approval.
- Manage dependencies with `task.dependency.add`, `task.dependency.remove`, and `task.dependency.list`. Before dispatch, verify that every prerequisite task has outcome `completed`. If a dependency is locked or its state cannot be verified, do not start work. Todoing stores dependency edges and prevents cycles; Manifest decides readiness.
- `actor_id` is attribution, not authentication. The Orchestrator sends every request; for a Review, set the envelope actor ID to the stable identity of the Reviewer role/session.

### 6.2.1. Todoing-only mode (OpenSpec disabled)

Use this mode when `components.todoing.enabled: true` and
`components.openspec.enabled: false`. Todoing manages standalone project
tasks; OpenSpec is not a required dependency.

1. At the start of a work session, list active tasks with `task.list`.
   Reuse a matching existing task instead of creating a duplicate. If a
   task's state cannot be verified (for example, it is hidden because
   another owner holds its lock), stop and resolve the uncertainty; do not
   assume the task is absent.
2. Create a task with `task.create` only for an independently meaningful
   outcome, not for every implementation step. Keep subtasks, technical
   steps, and intermediate actions inside the parent task description.
   Check for an existing active task with the same outcome before creating.
3. New tasks start in `backlog`. Put the concise outcome in `title`, and
   the goal, boundaries, and acceptance criteria in `body`. Do not add
   priorities; the current Manifest configuration does not use them. Update
   an existing task only after `task.get`, using `task.update` for `title` or
   `body`. A material scope or acceptance-criteria change after approval
   requires a new explicit user decision and a new baseline via
   `task.version.approve`.
4. Only an explicit user instruction to execute the work authorizes
   `backlog → ready`. A request to discuss, analyze, or prepare a plan is
   not implementation approval. After approval, call `task.status.set` to
   `ready`, read the current version with `task.get`, and record it with
   `task.version.approve`.
5. Add or remove prerequisite links with `task.dependency.add` and
   `task.dependency.remove` only for real dependencies between independent
   tasks. Before starting, inspect them with `task.dependency.list`. Every
   prerequisite must have outcome `completed`. Do not start when a dependency
   is incomplete, locked, or cannot be verified.
6. Then follow §6.3: acquire the lock, transition `ready → in_progress`,
   and heartbeat before each blocking role-agent run. Only the Main
   Orchestrator calls the Todoing API.
7. After each meaningful Git commit, attach it with `task.commit.add`.
   Before handing the result to the Reviewer, move the task to `review`;
   use the Review API in §6.4. On approval, move it to `verified`.
8. Complete the task after acceptance checks: record the final Git SHA with
   `task.commit.finalize`, move the task to `completed`, and release the
   lock. Do not run OpenSpec archive or create an `openspec.change`
   reference in this mode.
9. Cancel only after the user's decision, using `task.cancel`; do not run
   OpenSpec archive. After an interruption, reconcile Todoing and Git before
   retrying any operation.

`task.list` omits tasks locked by another owner. Manifest permits only one
active global task and one Main Orchestrator per project; parallel
Orchestrators are not used.

### 6.3. Lock custody and execution

The Orchestrator is the sole Todoing API client and lock-token custodian:
1. Before work, call `task.lock.acquire`; keep `owner_id`, `lock_token`, `fencing_generation`, and `expires_at` in protected main-session state.
2. Immediately after acquisition, move the task `ready → in_progress` with `task.status.set`, supplying the token in the envelope.
3. Call `task.lock.heartbeat` immediately before each blocking subagent run. A 720-second lease covers the 600-second hard timeout plus 120 seconds of margin.
4. Do not send heartbeats while the subagent is running. Never give the token to a role agent; role agents never call Todoing.
5. Include the token in the envelope of every owner request and use the current owner ID and generation in args. On `stale_lock`, stop using the old token.
6. Release the lock with `task.lock.release` after task completion or confirmed cancellation.

`actor_id` is attribution, not authentication. The rule that the Main Orchestrator coordinates Todoing calls is the agreed procedural authority boundary. Technical isolation of role agents is intentionally not implemented and is not a workflow compliance criterion: Todoing does not block direct API calls from another process. Do not claim that direct access is technically denied; assess compliance with the procedural rule from agent actions.

### 6.4. Status and Review

- Before handing work to the Reviewer, move the task to `review` using `task.status.set`.
- Record the Review with `task.review.add`: stable `review_id`, reviewed `version_no`, `reviewer`, outcome, and ordered `comments` array.
- On `approved`, move the task to `verified`.
- On `changes_requested`, Todoing atomically increments `revision_count` once; after recording the Review, return the task to `in_progress`.
- The same `review_id` and payload is a no-op; a different payload with the same ID is a conflict. Never use the number of task versions as a revision counter.

### 6.5. Completion and cancellation

Successful completion MUST follow this order:
1. Review approved; status is `verified`.
2. Acceptance checks across Todoing, OpenSpec, and Git.
3. Run `openspec archive <change-id> --yes`; delta specs are merged into permanent specs.
4. Git merge according to project rules.
5. `task.commit.finalize` with the final merge commit SHA.
6. `task.status.set` to `completed` (the transition also sets outcome `completed`).
7. `task.lock.release`.

Any agent may recommend cancellation with a reason; only the user may approve it. After approval, perform these steps in order:
1. `task.cancel` with a reason.
2. Run `openspec archive <change-id> --yes --skip-specs`; the change is archived without modifying permanent specs.
3. `task.lock.release`.

Retain the external reference. Archiving alone is not cancellation.

### 6.6. Snapshot and restore

- Create snapshots with `store.snapshot`; never copy the active SQLite file.
- Verify a snapshot with `store.snapshot.verify` before transfer or restore; retain its SHA-256.
- `store.snapshot` and `store.snapshot.restore` are rejected while task locks are active.
- `store.snapshot.restore` restores only Todoing SQLite, requires the same Project ID and schema, and creates a safety snapshot under `.todoing/backups/`.
- Restore is destructive: perform it only with explicit user approval and pass the retained `expected_sha256`.
- Restore does not undo Git commits or OpenSpec archives. Reconcile Todoing, OpenSpec, and Git before resuming work.

### 6.7. Recovery

Restoring Todoing from a snapshot rolls back only Todoing's SQLite state; it does not undo OpenSpec archives or Git commits. After restore, reconcile all three systems before repeating any operation.

After interruption, first reconcile actual state: Todoing via `task.get`, `task.version.list`, `task.history.list`, `task.review.list`, `task.external-ref.list`, and `task.dependency.list`; OpenSpec (change and archive); Git (branch, merge, SHA). Never blindly repeat a non-idempotent operation.
- If the `task.lock.release` response was lost:
  1. Call `task.lock.heartbeat` first.
  2. Retry release only after ownership is confirmed.
- On `lock_expired`, wait for lease expiry plus the 60-second grace period, then call `task.lock.recover`; use only the new token and fencing generation.
- On `stale_lock`, never use the old token again.
- After a failure between archive and merge, do not archive again; reconcile and continue with merge.
- After a merge without a final marker, obtain the actual merge SHA and call `task.commit.finalize`.
- After `completed`, do not repeat `task.status.set` or `task.complete`; verify state and release the lock only after confirming ownership.
- During cancellation, do not repeat `task.cancel` if outcome is already `cancelled`; reconcile and perform only the missing steps.

Todoing, OpenSpec, and Git do not share a transaction. Stop and escalate to the user if state is ambiguous.


### Individually selectable context files

Each context file is controlled by its own `context_files.<id>.enabled` switch in `.manifest/manifest.yaml`. Supported IDs are `agents`, `llm-navigation`, `versioning`, `releases`, `logging`, `code-rules`, `test-rules`, `commit-rules`, `version`, and `llmignore`. All switches default to `false` for new projects. A file is connected only when its own switch is enabled. Disabling a switch never deletes an existing file. Existing configurations without the `context_files` section are not changed automatically; context-file installation is deferred until a separate, approved migration is designed.
