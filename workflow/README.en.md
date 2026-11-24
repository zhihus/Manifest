# OpenSpec Protocol

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.1.1**  
> **Updated: 2026-11-24**  

# Description
Process for working with LLM agents on the OpenSpec pipeline; task
rules live in `openspec-rules.md`.

Sequential execution is a Manifest rule: agents run one at a time,
no parallel dispatch (analysis, implementation, verification alike);
one global task per project at a time.

## 1. Roles

The pipeline exists inside the **Orchestrator** context (the main session /
conductor). It never performs a specialist's job: it restores pipeline state,
dispatches the right subagent at each step, checks the agent's report, and
gates the transition to the next step. This preserves the core invariant:
**no role ever checks its own work.**

| Step | Artifact | Agent | Input → Output |
|---|---|---|---|
| — | pipeline state | Orchestrator (always GLM-5.3 Flash) | runs steps, gates transitions |
| 0 | task in Todoing | Analyst | user's Backlog work → approved task, "To Do" |
| 1 | proposal.md | Analyst | user's words → "why / what" |
| 2 | spec.md | Analyst | proposal → scenarios, edge cases, PBT |
| 3 | design.md | Architect | proposal + spec → solution (optional) |
| 4 | tasks.md | Planner | spec + design → atomic task checklist |
| 5.1 | tests | Tester | spec properties → tests before code |
| 5.2 | code or document | Implementer / Documenter | tasks + spec → implementation |
| 6 | verify.md | Reviewer | artifacts + spec → ✅/❌ report |
| 7 | archive | Orchestrator | verify all ✅ → specs updated |

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

Two distinct roles, in that order.

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

Todoing is the source of truth for task state, versions, history, locks, and Reviews. Manifest owns OpenSpec, Git, and orchestration policy. The main Orchestrator is the only Todoing API client.

### 6.1. Bootstrap and Project ID

1. Verify that the user-installed binary is available with `todoing version`. Manifest does not install or update Todoing.
2. If both `.manifest/project-id` and the SQLite store are absent, generate a UUIDv4 and create the file atomically without overwriting an existing file.
3. If the store exists but the Project ID is missing, stop. Do not generate a replacement ID or call `store.init`.
4. If the Project ID exists, reuse it unchanged. For an existing store, call `store.info` and `store.verify`; an ID mismatch or integrity failure is a hard stop.
5. Inspect `.todoing/config.toml`. If the store already exists but the config is missing, stop; do not create a configuration with unknown policy over an existing store. If the store is absent, create the config only when there are no legacy Markdown tasks or `index.json`. Never overwrite an existing config; inspect it and stop if it is incompatible.
6. Recommended configuration: `format_version = 1`; statuses `backlog`, `ready`, `in_progress`, `review`, `verified`, `completed`; only `completed` maps to `outcome = "completed"`. Allowed transitions: `backlog → ready → in_progress → review`; from `review` to `in_progress` or `verified`; from `verified` to `completed`.
7. Set `[locking]` to `lease_seconds = 720`, `heartbeat_seconds = 180`, and `recovery_grace_seconds = 60`. These values are required for the lock protocol below.

Recommended `.todoing/config.toml` for a new project:

```toml
format_version = 1

[locking]
lease_seconds = 720
heartbeat_seconds = 180
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
label = "Review"
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

One OpenSpec change maps to one Todoing task:
- Create the task with `task.create` and status `backlog`.
- Add a project-scoped reference with `task.external-ref.add`: namespace `openspec.change`, value equal to the change directory ID, relation `implements`, scope `project`.
- Allow `backlog → ready` only after explicit user approval. Then record the current version as the baseline with `task.version.approve`.
- Do not dispatch implementation, acquire a lock, or move the task to `in_progress` before approval.
- Manage dependencies with `task.dependency.add`, `task.dependency.remove`, and `task.dependency.list`. Before dispatch, verify that every prerequisite task has outcome `completed`. If a dependency is locked or its state cannot be verified, do not start work. Todoing stores dependency edges and prevents cycles; Manifest decides readiness.
- `actor_id` is attribution, not authentication. The Orchestrator sends every request; for a Review, set the envelope actor ID to the stable identity of the Reviewer role/session.

### 6.3. Lock custody and execution

The Orchestrator is the sole Todoing API client and lock-token custodian:
1. Before work, call `task.lock.acquire`; keep `owner_id`, `lock_token`, `fencing_generation`, and `expires_at` in protected main-session state.
2. Immediately after acquisition, move the task `ready → in_progress` with `task.status.set`, supplying the token in the envelope.
3. Call `task.lock.heartbeat` immediately before each blocking subagent run. A 720-second lease covers the 600-second hard timeout plus 120 seconds of margin.
4. Do not send heartbeats while the subagent is running. Never give the token to a role agent; role agents never call Todoing.
5. Include the token in the envelope of every owner request and use the current owner ID and generation in args. On `stale_lock`, stop using the old token.
6. Release the lock with `task.lock.release` after task completion or confirmed cancellation.

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

### 6.6. Recovery

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
