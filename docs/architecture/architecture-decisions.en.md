# Architecture Decisions — Manifest

**Statuses:** **Accepted** (A), **Preliminary** (P), **Deferred** (D),
**Unresolved** (U), **Done** (DN — analytical/documentation work),
**Not implemented** (NI). Sources: brief v0.3.1, audits, Todoing
decisions (PR #1 todoing-x: PRODUCT.md, docs/architecture/decisions.md),
discussions of 2026-11-20/21. Auditor recommendations are not
decisions. Accepting a decision is not implementing a feature:
implementation is marked "NI". English translation of the
authoritative Russian edition (`architecture-decisions.ru.md`).

**DN — completed analytical work:** architecture-audit.ru.md;
todoing-manifest-integration-audit.ru.md; architecture-decisions.ru.md;
role-model-decisions.ru.md; the target Todoing documents in PR #1.

## 1. Principles

- A: Git is the mandatory foundation; changes within approved tasks;
  OpenSpec is mandatory (except automatic Manifest operations).
- A: Manifest ↔ Todoing — only via CLI and a versioned JSON contract,
  no direct storage reads.
- A: Todoing provides universal mechanisms and hooks without Manifest
  rules; Manifest defines the powers.
- A: Sources of truth: Todoing — tasks and history; OpenSpec —
  requirements; Git — code.
- A: Control — barriers at all stages; templates — centralized;
  AI-harness settings — outside Manifest.
- U: Trust model (technical guarantees vs procedural rules).

## 2. Components

| Component | Decision |
| --- | --- |
| Manifest Core | A: architecture, standards, templates |
| manifest-init | A: analysis, interview, Preflight, installation |
| Todoing | A: tasks, Kanban, history, versions, CLI/JSON |
| OpenSpec | A: specifications, decomposition, execution |
| compress-context | U: role in the MVP undefined |
| context-files-guard | A: context file protection |

## 3. manifest-init

- A: Preflight is mandatory; on failure the installation does not
  start.
- A: Existing files are not overwritten; name conflicts are recorded;
  no auto-merge; disabled templates go to the archive.
- U: Re-running manifest-init: file ownership classes.
- U: Hook strategy when existing hook managers are present.
- U: Canonical file names of the set (Brief vs repository diverge).

## 4. Todoing

- A: Each project gets its own task store. A shared overview is D.
- A: Two result statuses: "Done" and "Cancelled" — statuses, not
  archiving functions.
- A: Project identifier: mandatory at integration; the CLI must
  receive it. U: the way to pass/pin/protect it in the AI harness is
  undefined; AI-harness configuration is outside Manifest.
- A: Statuses are extensible and user-configurable; Manifest provides
  a recommended configuration without imposing it.
- A: History is complete, immutable, append-only; every successful
  save creates a new version; the approved version is the checkpoint.
- A: Physical deletion is forbidden; task IDs are not reused.
- A: Archiving is a separate function, not a consequence of result
  statuses; archiving is possible regardless of status. Archived
  tasks are excluded from the board, available in a separate list;
  restoration is provided. Agents may read unlocked archived tasks
  when elaborating tasks in Backlog; a locked archived task remains
  subject to the exclusive lock. A cancellation reason is optional.
- A: Parallel work — an exclusive lock for the whole agent session,
  including blocking reads by other clients; capture is done by the
  locking operation; it holds until explicit release or automatic
  expiry; the expiry mechanism must account for agent crashes.
- A: Changes to a task, its history and state are atomic.
- A: System operations (versioning, history, metadata) run
  automatically on events, not at the agent's discretion.
- A: Hooks/events are universal, optional; a missing handler does not
  break the operation. Todoing contains no knowledge of Manifest or
  OpenSpec.
- A: Standalone Todoing use requires no integration; Manifest's
  restrictions apply only under integration.
- A: Full export/import is architecturally agreed; D: implementation
  is outside the MVP.
- P: SQLite is a preliminary choice, pending a technical check.
- D: GUI, shared task overview.
- U: Manifest status map (6) ↔ Todoing.
- NI (not implemented in todoing-x): history, versions, dependencies,
  locks, archiving, the new versioned API, Project ID. The current
  implementation is a prototype.

## 5. OpenSpec and Todoing

- A: One Todoing global task = one OpenSpec global task; Todoing
  stores links to the change and the final commit/merge.
- U: Status synchronization across the three systems (transitions,
  owner, source of truth); the term "global task".

## 6. Roles and powers

- A: Roles (7): Orchestrator, Executor, Code Reviewer, Documentation
  Author, Documentation Reviewer, Tester, Analyst; the executor does
  not verify their own work. The Tester prepares tests before
  implementation (TEST FIRST). Decided 2026-11-21
  (role-model-decisions.ru.md).
- A: The Analyst works with the user in Backlog, analyzes context,
  dependencies, specifications, creates the task in Todoing (the
  permission is realized through joint work in Backlog); the user
  moves the task to "Ready" themselves.
- A: The orchestrator organizes the execution of the approved task;
  always uses the GLM-5.3 Flash model; does not substitute for the
  Analyst and does not approve tasks for the user. No models are
  pinned to other roles; model distribution is D.
- A: Reviewer findings go to the orchestrator; it re-runs the
  executor until the findings are resolved; blocking errors are
  escalated to the user.
- A: One model may be used for different roles; each role gets a
  separate agent with its own context and instructions.
- U: General escalation on Orchestrator/Reviewer disagreement outside
  the rework loop; the status of the Architect/Planner roles of the
  workflow README.

## 7. Git, branching, releases

- A: The main branch is develop; a task gets its own branch; merging
  and closing are done by the orchestrator. Intermediate commits are
  allowed. VERSIONING.md and RELEASES.md are separate documents.
- A: Sequential execution is a mandatory rule: agents run
  sequentially, parallel execution is forbidden (analysis,
  implementation, verification); one global task per project at a
  time; moving on when blocked — only without a dependency on the
  blocked task. Decided 2026-11-21 (role-model-decisions.ru.md).
- P: Technical blocking of parallel execution — via harness
  mechanisms (e.g. ZCode hooks); U: a universal guarantee for all
  harnesses.
- U: Who resolves merge conflicts and whether a review is needed
  afterwards.

## 8. Control and safety

- A: Control points: branches, commits, Todoing statuses, OpenSpec
  state, handover for review, review, merge, closing.
- A: The rule "status changes — only via the Todoing CLI" applies to
  Manifest integration. Standalone use is not restricted by it:
  Todoing provides universal mechanisms, and the mandatory policy is
  defined by the integrating system.
- A: Context files are protected: priority — universal Git
  mechanisms, second layer — harness mechanisms (e.g. ZCode); for
  other harnesses — principles and a sample implementation. Protected
  files — a centralized list. A technical prohibition outranks agent
  instructions.
- A: Controlled File Update: the agent files a request; the user
  approves it and separately triggers the apply; Manifest verifies
  and applies the changes. The agent never receives direct write
  permission to a protected file.
- NI: the Controlled File Update mechanism and the centralized list
  are not implemented.
- U: Technical guarantees vs procedural ones are not separated.
- U: Hooks do not intercept branches; Preflight checks for Todoing.

## 9. Backup and portability

- A: Backup is provided by Manifest — a mandatory requirement; Git is
  not a backup; implementation is deferred; the minimum is a separate
  physical disk; remote storage is allowed.
- D: Strategy, periodicity, triggers, rotation, restoration,
  export/import format — separate design work.

## 10. Project types

- A: Code / Documentation / Mixed — configurations of a single
  system; the track is determined by the model, completeness is
  checked by scripts.
- U: Configuration format (name, location, flags) — Brief §13.

## 11. MVP

Included (A): Manifest Core; templates; manifest-init; Preflight;
installing files with overwrite protection; hooks and control
scripts; Todoing and OpenSpec integration; consistency control of the
three systems; context-files-guard; Git projects. Archiving as a
function is agreed; its inclusion in the MVP is unresolved.
MVP precondition (P): the minimal Todoing contract — link fields,
contract version, history, versions, locks.
Outside the MVP (D): auto-merge of context files; migration of
developed context systems; template auto-updates; automatic Preflight
fixes; GUI; shared overview; implementing export/import and backup;
remote storage.
2026-11-22: brief v0.3.1 was brought in line with this section — the
archiving point in Brief §12 is marked "inclusion in the MVP is
unresolved"; the decision remains with the user.

## 12. Unresolved questions (summary)

Trust model (§1, §8); status map ↔ Todoing, project ID via the AI
harness (§4); three-system synchronization, "global task" (§5);
escalation outside the rework loop, Architect/Planner (§6); merge
conflicts (§7); re-running manifest-init, file ownership, hooks, file
names (§3); configuration (§10); compress-context (§2); template
versions (Brief §13); recovery after failures; archiving in the MVP
(§11).
Decided 2026-11-21: Tester and Analyst in the role model (§6); the
parallel-execution ban (§7).
