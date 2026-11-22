# Architecture Roadmap — Manifest

**Version:** 1.0.0  
**Status:** working edition  
**Purpose:** separate the MVP scope from the subsequent development
stages of Manifest; record the MVP preconditions and unresolved
technical questions. Sources: `architecture-brief.ru.md` v0.3.1
(§12, §13), `architecture-decisions.ru.md` (§11, §12),
`workflow/roadmap.en.md` v1.1.0. This document introduces no new
decisions. The Russian edition (`architecture-roadmap.ru.md`) is
authoritative; this is its English translation.

## 1. MVP

### 1.1. Included in the MVP

1. Manifest Core (architecture, standards, rules, configuration,
   templates).
2. Structure and set of approved templates.
3. `manifest-init` (analysis, interview, configuration, Preflight,
   installation).
4. Configuration of project types and tracks (Code / Documentation /
   Mixed).
5. Preflight (no auto-fixing — diagnostics and an understandable
   report).
6. Installing context files with overwrite protection.
7. Installing Git hooks and control scripts.
8. Integration of the Todoing and OpenSpec processes.
9. Consistency control for Todoing ↔ OpenSpec ↔ Git.
10. Connecting `context-files-guard`.
11. Support of new and existing Git projects with a missing or
    partial set of context files.

Archiving of disabled templates: the function is agreed, **its
inclusion in the MVP is unresolved** — requires a user decision
(`architecture-decisions.ru.md` §11).

### 1.2. MVP precondition

The minimal Todoing contract (decision status — preliminary): link
fields to OpenSpec/Git, contract version, history, task versions,
exclusive locks.

### 1.3. Not part of the MVP (recorded)

- Automatic merging of existing context files with templates.
- Full migration of projects with their own developed context system.
- Automatic template updates in all previously connected projects.
- Automatic fixing of Preflight-detected problems.
- Todoing GUI and a shared task overview.
- Implementing export/import and backup (the contract is agreed, the
  implementation is deferred).
- Remote backup storage.

At the same time, the possibility of further development is accounted
for in the architecture.

## 2. Roadmap (after the MVP)

Roadmap items do not affect the MVP scope and are executed after it
is fixed:

1. Template archiving (if the user decides to move it out of the
   MVP).
2. Template auto-updates in connected projects.
3. Auto-fixing part of the Preflight problems (the boundary between
   auto-fixing and diagnostics — Brief §13).
4. Todoing export/import and backup.
5. A shared cross-project task overview, Todoing GUI.
6. Full migration of developed context-file systems.

Workflow level (see `workflow/roadmap.en.md` v1.1.0):

- the `commit-msg` hook (commit message validation);
- parser extensions: directory walk, scheduled runs;
- rules for documentation projects: filling in
  `doc-content-rules.template.md`, git workflow for doc projects;
- the `manifest-init` distribution build with the exclusion check
  (without `scripts/verify.sh` and `scripts/hooks/`).

## 3. Unresolved questions

The full register — `architecture-decisions.ru.md` §12 and
`architecture-brief.ru.md` §13. Questions blocking the MVP:

| Question | Blocks |
| --- | --- |
| Minimal Todoing contract | §1.2 — MVP precondition |
| Project configuration (name, location, format, flag schema) | manifest-init |
| Git initialization of a new project without a repository | manifest-init |
| Installing hooks without breaking existing mechanisms | §1 item 7 |
| Context file protection before writing | §1 item 6, context-files-guard |
| Todoing ↔ OpenSpec ↔ Git synchronization | §1 item 9 |
| Name conflicts with existing files | §1 item 6 |
| Versioning of installed templates | templates, roadmap item 2 |
| Formal definition of the 100% requirement for code | TEST FIRST |
| Manifest status map ↔ Todoing, Project ID | integration |

Non-blocking: trust model; escalation outside the rework loop; the
status of the Architect/Planner roles; re-running manifest-init and
file ownership classes; logging of control operations; archive
restoration; backup strategy; the role of compress-context in the
MVP.

## 4. Document maintenance rules

- The document reflects agreed decisions only; when a decision
  changes, `architecture-brief.ru.md` and
  `architecture-decisions.ru.md` are updated first, then this
  document.
- MVP and roadmap are kept separate: moving an item between sections
  requires a user decision and a record in the decision register.
- Historical materials (audits, decision drafts) are not deleted.
