# Manifest — Architecture Brief

**Version:** 0.4.1  
**Status:** working edition, synced with the decisions of the
2026-11-20/21 discussions and the 2026-11-22 protocol
(`architecture-session-2026-11-22.ru.md`)  
**Purpose:** fix the Manifest architecture and MVP scope before
technical design. English translation of the authoritative Russian
edition (`architecture-brief.ru.md`).

## 1. Purpose

Manifest is a system for governing the work of LLM agents in
Git-based projects.

Main goals:

- limit the independent decisions and actions of agents;
- ensure that changes are made only within approved tasks;
- standardize work with OpenSpec;
- separate implementation from independent verification;
- protect context files;
- automate process control;
- ensure traceability from task to commit and release.

Manifest is not tied to a specific AI harness. Configuring ZCode and
other harnesses remains the user's responsibility.

## 2. Architecture and components

Manifest is an ecosystem of independent components.

| Component | Purpose |
| --- | --- |
| **Manifest Core** | Architecture, standards, rules, configuration, templates |
| **manifest-init** | Analysis, initialization, connecting Manifest to projects |
| **Todoing** | Task management and Kanban |
| **OpenSpec** | Specifications, decomposition, task execution |
| **compress-context** | Context volume management |
| **context-files-guard** | Context file protection |

Git hooks and control scripts are implementation mechanisms of
Manifest, not separate ecosystem components.

`manifest-init` and the project initialization skill are one
component, not two.

Todoing, OpenSpec, compress-context and context-files-guard remain
independent. Manifest defines the rules of their joint operation.

## 3. Project types

Manifest supports three tracks:

- **Code** — projects with program code.
- **Documentation** — documentation projects.
- **Mixed** — projects of both kinds.

These are not three different Manifest architectures but
configuration variants of a single system.

### Determining the track

For a new project the model conducts an interview with the user.

For an existing project the model:

1. Studies the structure, documents and code.
2. Forms an understanding of the project.
3. Determines the presumed tracks.
4. Clarifies ambiguities with the user.
5. Proposes a configuration.

The model must not guess when information is insufficient.

The configuration is produced by the model; its completeness and
validity are checked by Manifest scripts.

### Project evolution

The model may discover a new track and propose a configuration
change.

After the user-approved flags change, `manifest-init` syncs the set
of connected templates.

Installing an already approved template does not require a separate
Todoing/OpenSpec task.

## 4. Templates and context files

### Template source

Reference templates are stored in a dedicated folder of the Manifest
repository.

All projects receive files from a single approved set. Re-approval
of each template at installation time is not required.

For the MVP a **single common template** is used (decided
2026-11-22). Specialized templates for different project types are
deferred to the roadmap.

### Mandatory base set

For all projects:

- `AGENTS.md` — the agent's core working rules.
- `llms.txt` — project description and additional context.
- `COMMIT_RULES.md` — commit rules.
- `VERSION` — current version.
- `VERSIONING.md` — versioning rules.
- `RELEASES.md` — release preparation and publishing rules.

`VERSIONING.md` and `RELEASES.md` are separate documents with
different purposes.

> Note (2026-11-22): no `RELEASES.md` template exists yet, so
> `manifest-init` in the MVP installs the five base-set files
> (without `RELEASES.md`); the file is added to a project manually
> once a template appears.

### Conditional templates

The conditional rule sets for code and documentation projects (below)
are not installed in the MVP: a single common template applies. This
section is kept as the basis for specialized templates at the roadmap
stage.

Code projects additionally connect rules for:

- coding;
- development;
- testing;
- logging.

Documentation projects connect rules for:

- creating and formatting documentation;
- verifying documentation.

Mixed projects receive both sets.

TEST FIRST is a common principle for all tracks. Verification methods
differ depending on the type of the result.

### Language

Manifest context files and rules are maintained in English.

The agent communicates with the user in the user's language.

### Working with existing files

At installation:

- missing files are added;
- existing files are not overwritten;
- name conflicts are recorded and reported to the user;
- no automatic merging of existing files with templates is performed.

Full migration of an already existing context-file system is deferred
beyond the MVP.

### Archive

Disabled templates are not deleted but moved to an archive folder.

The archive:

- is excluded from the LLM context via `.llmignore`;
- is additionally protected by `context-files-guard` and Git hooks;
- requires no separate log of connections and disconnections.

Automatic restoration of archived files is allowed only when a
dedicated algorithm is provided.

## 5. Initialization: manifest-init

`manifest-init` covers the full cycle of connecting Manifest to a
project:

1. Project analysis.
2. Interview and configuration.
3. Preflight.
4. Installing the approved templates.
5. Installing the control scripts.
6. Installing the Git hooks.
7. Final installation check.
8. Producing an understandable report.

### Working directory and configuration

The Manifest working directory is `.manifest` in the project root
(decided 2026-11-22). Settings are stored in a separate configuration
file. The configuration is stable and is not overwritten
automatically. Re-initialization is not provided. A mechanism
protecting against accidental overwrite is mandatory. The
configuration file format and the flag schema remain open questions
(§13).

### Preflight

Before any changes, the necessary conditions are checked:

- Git is present;
- project structure;
- access rights;
- write permission;
- required tools and dependencies;
- conditions for installing the control mechanisms.

If Preflight fails, the installation does not start.

Manifest must report the cause of the failure and the necessary
actions.

Automatic fixing of detected problems is not yet defined.

## 6. Git

Git is mandatory for all Manifest projects.

Local and remote repositories are supported. Work with a remote
repository goes through its working copy.

The main branch is `develop`.

Each global task gets its own branch created from `develop`. The
executors work in it.

Sequential execution is a mandatory Manifest rule. Agents run
sequentially; parallel execution is not allowed, including analysis,
implementation and verification. Only one global task runs at a time
within a project. When a task is blocked, moving to the next one is
allowed only if it does not depend on the blocked task; if there is a
dependency, execution waits for the block to be resolved. The
orchestrator starts the next agent only after the previous one
finishes.

After a successful review and the final check the orchestrator:

1. Merges the task branch into `develop`.
2. Ensures the links to Todoing and OpenSpec are preserved.
3. Closes the task.

Intermediate commits are allowed. One commit does not have to
correspond to one task.

### Merge conflict

A merge conflict is resolved by the Executor assigned by the
orchestrator (decided 2026-11-22). After the resolution, automated
tests and checks are mandatory. In addition, an independent review is
performed by an agent with a clean context. The executor does not
confirm the correctness of their own solution. The orchestrator
controls the result and performs the merge.

Todoing keeps references to the OpenSpec change and the final
commit/merge.

## 7. Task management: Todoing

Todoing is an independent task management and Kanban tool.

Any project change goes through a task, except for explicitly
provided automatic Manifest operations, such as installing an
approved template.

### Task creation

- The task is prepared by the Analyst together with the user at the
  Backlog stage.
- The Analyst analyzes the project context, previous tasks, their
  dependencies and specifications; creates the task in Todoing. This
  agrees with the rule "an agent creates tasks only with the user's
  permission": the permission is realized through joint work in
  Backlog.
- The user discusses the Analyst's proposals, adjusts them and, when
  needed, assigns rework.
- The user approves the task by moving it to "Ready" themselves.
  After that the orchestrator continues work on the task.
- Each task has an approved format, a naming template and strict
  numbering.
- Before creating a task, an existing similar task is checked for.
- Each task contains acceptance and verification criteria.
- Task dependencies are determined with the Analyst's participation;
  a new task is placed last in the list and analyzes the already
  updated list.

### Task preparation

In Backlog the user and the agent:

- clarify the content;
- remove duplicates;
- work out the solution;
- form acceptance criteria;
- determine the required checks.

Only after the user's approval is the task moved to "Ready".

### Kanban statuses

Todoing is the single source of the task status; Manifest does not
duplicate Todoing statuses and does not maintain a separate status
mapping (decided 2026-11-22). Manifest's internal stages are kept.
Manifest manages the sequence of stages and agent assignment.

| Status | Purpose |
| --- | --- |
| Backlog | Discussion and detailing |
| Ready | Task approved |
| In Progress | Implementation |
| In Review | Handed to the independent Reviewer |
| Verified | Reviewer confirmed the result |
| Done | Orchestrator ran the final check and closed the task |

When the Reviewer has findings, the task returns to "In Progress".

No separate rework statuses are introduced. A `revision_count`
counter and a findings history are provided.

The user sets the priority and order of tasks. By default tasks are
executed in numbering order unless the user says otherwise.

The user does not perform technical acceptance and does not close
tasks.

### Task cancellation

Any agent may recommend cancelling a task with a rationale (decided
2026-11-22). Only the user confirms the cancellation. After the
confirmation the orchestrator changes the task status in Todoing and
archives the related OpenSpec change via the standard Archive
mechanism. The main OpenSpec specifications are not updated.
Archiving an OpenSpec change is the OpenSpec Archive mechanism,
unrelated to the archive of disabled templates (§4).

### Todoing integration

Todoing is an independent Rust CLI, not dependent on Manifest; it
manages tasks only. Manifest owns the integration policy and the
consistency of Todoing, OpenSpec and Git.

- Interaction is only via the CLI and a stable versioned JSON API;
  direct reading of the storage is forbidden.
- Statuses are configured by the user; Manifest provides a
  recommended configuration without imposing it.
- Dependencies, operation history, versions and exclusive task locks
  are mandatory.
- History is immutable and append-only; every successful save creates
  a task version.
- Locking is exclusive for the whole agent session, including
  blocking reads by other clients; automatic expiry on agent crash is
  provided.
- Physical deletion of tasks is not allowed; identifiers are not
  reused.
- Archiving is a separate function, not a status: archived tasks
  remain readable and restorable.
- Hooks/events are universal and optional; Todoing contains no
  knowledge of Manifest or OpenSpec.
- SQLite is a preliminary storage choice; the final decision requires
  a technical study.
- Import/export and backup are follow-up tasks; backup is provided by
  Manifest, Git is not a backup.
- Project ID is mandatory at the integration boundary; the transfer
  mechanism is yet to be designed.

## 8. OpenSpec

OpenSpec is mandatory for all changes except explicitly provided
automatic Manifest operations.

The relation between Todoing and OpenSpec:

**One Todoing global task = one OpenSpec global task.**

OpenSpec provides the internal elaboration of the task:

- specifications;
- requirements;
- design, when needed;
- decomposition;
- subtasks;
- checks;
- recording of execution in `tasks.md`.

The decomposition depth depends on the task complexity. The mandatory
nature of OpenSpec does not depend on task size.

Todoing remains the external source of the task. OpenSpec does not
replace Todoing.

The Todoing task state and the OpenSpec state must stay consistent.

## 9. Agent roles

Manifest defines roles and powers independently of the harness in
use.

Mandatory roles:

| Role | Responsibility |
| --- | --- |
| Orchestrator | Process management, coordination and final acceptance; uses GLM-5.3 Flash |
| Executor/developer | Implementation of program code |
| Code Reviewer | Independent code verification |
| Documentation Author | Creating and editing documentation |
| Documentation Reviewer | Independent documentation verification |
| Tester | Preparing tests before implementation per TEST FIRST |
| Analyst | Preparing tasks together with the user in Backlog |

The executor does not verify their own work. The orchestrator does
not substitute for the Analyst at the task preparation stage and does
not make task approval decisions for the user.

The Reviewer:

- is independent of the executor;
- has a separate context and instructions;
- verifies the result against the task criteria;
- either accepts the work or returns it for rework.

The orchestrator:

- manages execution;
- controls OpenSpec;
- organizes independent checks;
- performs the final check;
- merges the branch;
- closes the task.

A separate audit of agent behavior is not required: control is
provided by tasks, powers, OpenSpec, the Reviewer and automated
checks.

Reviewer findings are passed to the orchestrator; the orchestrator
re-runs the executor until the findings are fully resolved. On a
blocking error the orchestrator escalates the problem to the user.

Each role gets a separate agent with its own task, context and
instructions; the same model may be used for different roles. Model
assignment per role is not fixed and is deferred; configuring agents
and their permissions in a specific AI harness is the user's
responsibility.

## 10. TEST FIRST and quality

TEST FIRST applies to all project types.

### Program code

TDD and SDD are used:

- requirements and specification are formed before implementation;
- tests are developed before the corresponding code;
- the result passes an independent Code Review.

Testing of program code is mandatory. The 100% requirement must be
reflected in the testing rules with an unambiguous definition of the
criterion.

### Documentation

Automated checks are provided for:

- structure and mandatory sections;
- presence of files;
- correctness of links;
- Markdown and YAML;
- conformance to Manifest templates;
- conformance of the documentation to the actual project state.

Structural checks are performed by scripts. Content verification is
performed by the Documentation Reviewer.

## 11. Automated control

Manifest control scripts are the same for all connected projects.

Git hooks and control scripts are installed automatically through
`manifest-init`. The existing mechanisms of Git and the AI harness
are used; Manifest does not develop its own hook manager (decided
2026-11-22). Hooks run the Manifest control scripts. Separate
implementations per AI harness are not part of the MVP unless
necessary.

Control operates at all stages, not only before task completion.

Mandatory control points:

- branch creation and switching;
- commits;
- Todoing status changes;
- OpenSpec state changes;
- handover for review;
- Reviewer results;
- branch merging;
- task closing.

The main goal of control is to ensure consistency:

**Todoing ↔ OpenSpec ↔ Git.**

Checks must work as a sequence of barriers. Relying only on the final
check is unacceptable.

### Context file protection

- Priority is given to universal Git mechanisms; the second layer is
  harness-specific mechanisms (for example ZCode); for other harnesses
  the principles and a sample implementation are recorded.
- Protected files are defined by a centralized list.
- A technical prohibition has priority over agent instructions.
- Controlled File Update: the agent files a change request for a
  protected file; the user approves the request and separately
  triggers the apply; Manifest itself verifies and applies the
  changes. The agent never receives direct write permission to a
  protected file.

## 12. MVP scope

### Included in the MVP

1. Manifest Core.
2. Structure and set of approved templates (for the MVP — a single
   common template, decided 2026-11-22).
3. `manifest-init`.
4. Configuration of project types and tracks.
5. Preflight.
6. Installing context files with overwrite protection.
7. Installing Git hooks and control scripts.
8. Integration of the Todoing and OpenSpec processes.
9. Consistency control for Todoing, OpenSpec and Git.
10. Connecting `context-files-guard`.
11. Archiving of disabled templates (the function is agreed; its
    inclusion in the MVP is unresolved — see
    `architecture-decisions.ru.md` §11).
12. Support of new and existing Git projects with a missing or
    partial set of context files.

### Outside the MVP

- Specialized templates for different project types (decided
  2026-11-22).
- A separate approved process for updating Manifest files in
  connected projects; the update is not a re-initialization, the
  process details are open (decided 2026-11-22).
- Automatic merging of existing context files with Manifest
  templates.
- Full migration of projects with their own developed context system.
- Automatic template updates in all previously connected projects.
- Automatic fixing of any Preflight-detected problems.

At the same time, the possibility of further development must be
accounted for in the architecture.

## 13. Unresolved technical questions

These questions do not change the accepted architectural principles
but require decisions before implementing the corresponding
mechanisms.

| Question | What must be determined |
| --- | --- |
| Project configuration | File format and flag schema (name and
  location defined 2026-11-22: `.manifest`, a separate file) |
| Git initialization | Whether `manifest-init` creates a Git repo for a new project without one |
| Git hooks | Compatibility of installation with the project's
  existing hook managers |
| File protection | How to block context file changes before writing, not only at commit |
| Synchronization | Technical mechanism for Todoing/OpenSpec/Git
  consistency at every stage (no status map; decided 2026-11-22) |
| Manifest file updates | Details of the approved update process for
  connected projects |
| Preflight | Which problems can be fixed automatically and which only diagnosed |
| Templates | How to determine the installed template version and organize later updates |
| Archive | Conditions and mechanism of automatic restoration |
| Git workflow | The exact task branch naming template |
| Testing | Formal definition of the 100% requirement for program code |
| File conflicts | How the agent should act when an existing file with the same name is found |
| Logging | Which control operations it is really needed for |
| Architect/Planner roles | Status of these workflow-README roles in
  the mandatory model is undefined |

## 14. Architectural constraints

The following principles are mandatory:

1. Git is the mandatory foundation of the work.
2. An agent does not receive the power to create tasks without the
   user's permission.
3. Changes are made within approved tasks.
4. OpenSpec is mandatory for changes.
5. The executor does not verify their own work.
6. Context files are protected from independent modification.
7. Existing project files are not overwritten at initial connection.
8. Control operates at all stages of the task life cycle.
9. Manifest does not manage the settings of a specific AI harness.
10. All reference templates are stored centrally in the Manifest
    repository.

---

**Final concept:** Manifest turns the work of LLM agents from a set of
independent actions into a governed process with formalized tasks,
specifications, roles, independent verification and automated
barriers.
