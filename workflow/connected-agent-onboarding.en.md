# Connected Project Agent Guide

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.1.0**  
> **Updated: 2026-11-28**

# Description
Temporary context until Manifest attaches generated role/process guidance.

## 1. Startup

The Main Orchestrator must:
1. Read consumer AGENTS.md and check .llmignore access rules.
2. Validate .manifest/manifest.yaml, checksum, format_version, and switches
   against the installed Manifest schema.
3. Check OpenSpec/Todoing switches. OpenSpec must be enabled by default for
   every new consumer connection; disable it only on the user's explicit
   decision. If OpenSpec is unavailable or the schema does not support enabling
   it, stop and report the limitation.
4. If Todoing is enabled, verify binary, Project ID, config, and store per
   §6.1 of workflow/README.en.md.

Stop on checksum/schema/identity/store errors. Never repair config or reinitialize
an existing store automatically.

Invoke Todoing via `todoing --json api`; resolve its binary through
`TODOING_BIN` or PATH. Runtime must not depend on Manifest development scripts
or cache. Required baseline: commit
`653788a954d2a120db1beba854308982814d8222` or a verified descendant.
A version string does not prove provenance.

## 2. Operating modes

- **Both enabled:** coordinated mode; one Todoing task per OpenSpec change.
- OpenSpec is enabled by default for new connections. An existing
  `enabled: false` is not proof of an intentional user opt-out: enable it during
  onboarding using the schema and recalculate the checksum. Never disable it
  without the user's explicit decision.
- **Todoing only:** standalone tasks; no OpenSpec changes or fake
  `openspec.change` references.
- **OpenSpec only:** specifications without Todoing API/store.
- **Both disabled:** invoke neither component.

If a required component is disabled, tell the user. Never bypass switches or
change configuration without authorization.

## 3. When to create artifacts

Consultation, research, idea discussion, and one-off text edits do not by
themselves require a change/task.

Product behavior, architecture, public-contract, or material process changes
normally require an OpenSpec change. Before implementation, prepare proposal
and spec, plus design when needed and tasks.md. Creating artifacts is not
authorization to implement.

In coordinated mode, first find and reuse an existing linked task. Duplicates
are prohibited.

## 4. OpenSpec ↔ Todoing mapping

In coordinated mode only:
- One OpenSpec change maps to exactly one Todoing task.
- Task title equals the exact change directory ID.
- External reference: namespace `openspec.change`, value = change ID,
  relation = `implements`, scope = `project`.
- Before creation, inspect `task.list` and `task.external-ref.list`.
  Stop on ambiguity or conflicting matches.
- FRs, decomposition, and execution steps stay in tasks.md, not separate tasks.

Sources of truth: OpenSpec—requirements; Todoing—task status/outcome, versions,
history, locks, and Reviews; Git—actual changes and SHAs; Manifest—coordination.

## 5. Authority and lifecycle

The Main Orchestrator is the sole Todoing API client. Role agents work on assigned
artifacts; they do not create/update tasks, statuses, or locks, and never receive
lock tokens.

`backlog → ready → in_progress → review → verified → completed`

- `backlog → ready` requires explicit user authorization. Before lock/dispatch,
  the Orchestrator approves the baseline with `task.version.approve`.
- The Orchestrator controls transitions and dispatch; an independent Reviewer
  performs Review.
- `changes_requested` returns the task to `in_progress`; fixes require a new
  independent Review.
- `verified → completed` requires final checks and required OpenSpec/Git actions.
- Cancellation requires the user's decision. Archive does not replace status.

Detailed API, lock/heartbeat/fencing/recovery, Review records, final commit, and
partial-failure procedures: §§6.2–6.6 of `workflow/README.en.md` and
`docs/architecture/todoing-contract.ru.md`. After a lost response, reconcile
state before retrying; never blindly repeat a non-idempotent operation.

Authority is procedural: Todoing does not authenticate the user or prove consent;
`actor_id` is attribution, not identity proof.

## 6. Work cycle

Orchestrator restores state → clarifies requirements → Analyst prepares
proposal/spec → Architect prepares design if needed → Planner writes tasks.md
→ Orchestrator validates artifacts and creates/reuses the backlog task
→ user authorizes ready → Orchestrator approves baseline and dispatches roles
sequentially → independent Review → fixes if needed → final OpenSpec/Todoing/Git
reconciliation → report with links, Review, checks, and final SHA.

Parallel executors in one project are prohibited by the current workflow.
Use the OpenSpec doc-only path for documentation changes.

## 7. Recovery and replacement

After interruption, reconcile Todoing (task, versions, history, Reviews,
references, lock), OpenSpec (change/spec/archive), and Git (branch, worktree,
commit/merge SHA). If state is ambiguous, stop and ask the user; do not create
duplicates or blindly repeat operations.

This guide remains mandatory until Manifest generates and attaches role/process
context automatically. Retire it only after rules are migrated, entry points
preserved, all switch modes checked, and context discovery tested end to end.
