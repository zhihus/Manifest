# Connected Project Agent Workflow

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-28**  

# Description
Temporary mandatory agent context for projects connected to Manifest.

## 1. Purpose and scope

This document defines how an agent in a connected project uses Manifest, OpenSpec,
and Todoing as one change-management system.

It remains in force until Manifest can generate and attach separate context files
by role and process. When that mechanism is available, these rules must be
distributed across the appropriate files without losing any requirement.

This document does not replace the consumer project's AGENTS.md, architecture
documents, user decisions, or normative Manifest/OpenSpec/Todoing contracts.
If sources conflict, stop and report the conflict; do not choose a convenient
interpretation.

## 2. Mandatory startup checks

Before using the integration, the Main Orchestrator must:

1. Read the consumer project's AGENTS.md and check .llmignore access rules first.
2. Read .manifest/manifest.yaml and verify its SHA-256 against
   .manifest/manifest.yaml.checksum.
3. Check format_version and the actual component switches. Use the schema for
   that exact Manifest version; never infer key names from memory.
4. Select the operating mode from the switch values.
5. If Todoing is enabled, verify the compatible binary, Project ID, config,
   and store according to §6.1 of workflow/README.en.md.
6. Stop on a missing file, checksum mismatch, unsupported format, incompatible
   binary, Project ID mismatch, or store integrity error. Never repair or
   reinitialize existing state automatically.

A connected project invokes Todoing through `todoing --json api`. The permitted
binary resolution is an explicit `TODOING_BIN` or `todoing` on PATH, as defined
by the bootstrap contract. Do not depend at runtime on Manifest development
scripts or its repository cache. The required Todoing baseline is commit
`653788a954d2a120db1beba854308982814d8222` or a verified descendant. A version
string alone does not prove build provenance.

## 3. Integration modes

The mode is determined only by the project's actual configuration:

- **Both enabled:** coordinated mode; one Todoing task per OpenSpec change,
  with a maintained link and shared lifecycle.
- **Todoing enabled, OpenSpec disabled:** Todoing-only mode; manage standalone
  tasks, without OpenSpec changes or fake `openspec.change` references.
- **Todoing disabled, OpenSpec enabled:** OpenSpec-only mode; manage
  specifications without Todoing calls or a Todoing-store prerequisite.
- **Both disabled:** invoke neither Todoing nor OpenSpec.

If a user request requires a specification while OpenSpec is disabled, report
the disabled component and request authorization to enable it. Do not bypass
the switch or create a parallel, improvised specification system. Likewise,
do not use Todoing when it is disabled.

Never change switches automatically, create a store over existing data, or
rewrite user configuration. Change configuration only when authorized and
according to the bootstrap rules.

## 4. When to create a specification and task

First classify the request.

- Questions, advice, research, explanations, discussion, and isolated text
  edits do not by themselves require an OpenSpec change or Todoing task.
- Product behavior, architecture, public-contract, substantial process, or
  interdependent requirement changes normally require an OpenSpec change when
  OpenSpec is enabled.
- Before implementation, prepare proposal, spec, design when needed, and
  tasks.md according to the OpenSpec workflow. The specification defines the
  required behavior; implementation must not introduce undocumented requirements.
- When work must be tracked in Todoing, the Main Orchestrator checks existing
  tasks and reuses an existing linked task. Never create duplicates.
- When both components are enabled, one OpenSpec change and one linked Todoing
  task form a single workflow. When a component is disabled, use the matching
  mode in §3.

Creating artifacts does not authorize implementation. The agent must distinguish
proposal preparation, requirement approval, and permission to start work.

## 5. OpenSpec and Todoing relationship

In coordinated mode, these rules are mandatory:

1. Exactly one Todoing task corresponds to one OpenSpec change directory.
2. The Todoing task title exactly equals the change directory ID.
3. Store the relationship as a Todoing external reference:
   - namespace: `openspec.change`;
   - value: the exact change directory ID;
   - relation: `implements`;
   - scope: `project`.
4. Before creating a task, the Orchestrator checks `task.list` and
   `task.external-ref.list`. Reuse an existing linked task. Stop and reconcile
   ambiguity, conflicts, or multiple matches.
5. FRs, decomposition items, checklists, and implementation steps remain in
   `tasks.md`. They are not separate Todoing tasks.
6. Todoing is the source of truth for task status, outcome, versions, history,
   locks, and Reviews. OpenSpec is the source of requirements and specifications.
   Git is the source of actual change history and commit SHAs. Manifest
   coordinates consistency across all three.

Do not replace an external reference with a title match, a textual link in the
task description, or a custom mapping registry.

## 6. Authority and lifecycle

The Main Orchestrator is the only Todoing API client under the adopted procedure.
Role agents perform their assigned work on artifacts but do not create tasks,
change statuses, manage locks, or receive lock tokens.

The main Todoing lifecycle is:

`backlog → ready → in_progress → review → verified → completed`

- `backlog → ready` requires an explicit user decision. No agent may treat
  silence, a suggestion, or its own assessment as permission.
- On transition to `ready`, the Orchestrator records the approved version via
  `task.version.approve` before acquiring a lock or dispatching work.
- `ready → in_progress` is performed by the Orchestrator when work is actually
  assigned and started.
- `in_progress → review` is performed by the Orchestrator after the executor
  submits its result.
- Review is independent; an executor must not review its own work.
- On `changes_requested`, return the task to `in_progress`, resolve findings,
  and run a new independent Review.
- `review → verified` requires a successful Review.
- `verified → completed` requires the Orchestrator's final checks and completion
  of required OpenSpec/Git operations.
- Cancellation requires a user decision. An agent may recommend cancellation
  but must not make that decision.
- OpenSpec and Todoing archiving follows the prescribed completion order;
  archive state does not replace workflow status.

The exact API sequence, lock/heartbeat/fencing/recovery, Review records, final
commit marker, archiving, and partial-failure handling are defined in
§§6.2–6.6 of `workflow/README.en.md` and the
`docs/architecture/todoing-contract.ru.md` contract. Those normative documents
take precedence over this summary. Do not improvise or blindly retry a
non-idempotent operation after a lost response; reconcile actual state first.

Role authority is procedural. Todoing does not authenticate the user or prove
consent; `actor_id` is caller-supplied attribution, not proof of identity.

## 7. Agent operating sequence

For each change handled through OpenSpec:

1. The Main Orchestrator restores project state, switches, and active changes/tasks.
2. It clarifies requirements with the user and decides whether a formal change is needed.
3. The Analyst prepares proposal and spec; the Architect prepares design when
   required; the Planner creates verifiable tasks in tasks.md.
4. The Orchestrator checks artifact completeness and consistency, then creates
   or reuses the linked Todoing task in `backlog`.
5. The Orchestrator presents the prepared task and waits for the user's explicit
   authorization to move it to `ready`.
6. After authorization, it records the baseline, acquires the lock, and dispatches
   the required roles sequentially. Parallel executors in one project are
   prohibited by the current workflow.
7. An independent Reviewer checks the result against the spec. Findings are
   routed back to the executor through the Orchestrator.
8. The Orchestrator runs final checks, reconciles OpenSpec, Todoing, and Git in
   the prescribed order, and releases the lock.
9. The final report identifies the change/task, Review result, checks, and
   actual final commit SHA.

For documentation-only work, use the doc-only path in the existing OpenSpec
workflow. The absence of code does not waive specification or independent
review when the process requires them.

## 8. Recovery after interruption

After a restart, lost response, or partial failure, the Orchestrator must not
blindly repeat an operation. Reconcile:

- Todoing: task, versions, history, Reviews, external references, dependencies,
  and lock;
- OpenSpec: change state, delta-spec contents, and archive state;
- Git: branch, working tree, commit/merge SHA, and actual changed content.

If consistency cannot be restored unambiguously, stop and escalate to the user.
Never create a second task or Review, archive a change twice, or replace a final
SHA without checking actual state.

## 9. Ending the temporary mode

This document remains mandatory until Manifest can generate separate context
files by role and process and attach them automatically according to project
configuration.

During migration:

1. Distribute these rules across the appropriate general and specialized context files.
2. Preserve entry points and links so the agent cannot lose required instructions.
3. Verify that every switch mode is covered and that rules are neither duplicated nor contradictory.
4. Run an end-to-end check of context discovery and workflow behavior.
5. Remove the mandatory status of this temporary document only after all four checks pass.

Until then, agents must read and follow this document.
