---
name: manifest-init
description: Connect Manifest to a Git project, or manage standalone and coordinated Todoing tasks after connection. Adds only missing files and never overwrites user data.
---

# Manifest Init

Use when the user asks to connect, initialize, install, or repair Manifest, or to manage work in a connected Todoing project, with or without OpenSpec.

## Contract

- New projects receive only the configuration, enabled components, and individually selected context files.
- Existing projects are inspected first; only missing items are added.
- Existing files, settings, OpenSpec configuration and Todoing data are preserved byte-for-byte.
- Never archive, replace, merge, or delete a conflicting user file automatically.
- Never rewrite an existing .manifest/manifest.yaml or checksum.
- Verify checksum and schema before any write. Stop on mismatch, missing checksum, malformed switches or unsupported legacy format.
- No automatic migration.
- Todoing is enabled and OpenSpec is disabled by default; their switches are independent.
- Each context file has an independent `context_files.<id>.enabled` switch. All context-file switches default to false; disabling a switch never deletes an existing file.
- Supported IDs: `agents` (AGENTS.md), `llm-navigation` (llms.txt), `versioning` (VERSIONING.md), `releases` (RELEASES.md), `logging` (LOG_RULES.md), `code-rules` (CODE_RULES.md), `test-rules` (TEST_RULES.md), `commit-rules` (COMMIT_RULES.md), `version` (VERSION), `llmignore` (.llmignore).
- Seven optional controls default to false: workflow preflight, Git hooks/checks, OpenSpec validation, tests, review gate, additional gates.
- Mandatory integrity and installer safety checks are never switchable.
- temp/ must be excluded from Git; add the rule only if absent.
- Todoing's binary is installed/updated by the user. Never download it or initialize over an existing store/legacy data.

## Select the mode

Choose exactly one procedure:
- For a connection, initialization, installation, or repair request, use the Connection procedure.
- For task work in an already connected project, use Ongoing Todoing task management; follow the standalone or Todoing/OpenSpec coordination path according to the enabled component switches.
- Do not run the installer as part of ordinary task management.

## Connection procedure

1. Inspect Git status and project structure. Identify existing Manifest files, OpenSpec state, Todoing binary/config/database/legacy tasks, hooks and local conventions.
2. Run scripts/install.sh --project <path>. For a new project, component defaults may be overridden with --todoing enabled|disabled and --openspec enabled|disabled. Select individual context files during first-time initialization with repeated `--context-file ID=enabled|disabled`. For an existing configuration, edit only the chosen `context_files.<id>.enabled` value and recalculate the checksum sidecar (`sha256sum .manifest/manifest.yaml | awk '{print "sha256sum:" $1}' > .manifest/manifest.yaml.checksum`, or use `shasum -a 256` where `sha256sum` is unavailable); installer overrides are rejected for existing configurations. Existing configurations are immutable under automatic initialization; legacy configurations without per-file settings are preserved and require a separate explicit migration. For a new connection, confirm project name, purpose and tracks before writing. Existing valid project metadata is not re-interviewed.
3. Review installed, preserved and pending report sections. Existing destinations are never overwritten.
4. If Todoing is enabled, follow references/todoing-bootstrap.md. If its binary is unavailable, report the prerequisite and stop Todoing-dependent workflow; do not silently disable it.
5. Validate the resulting connection. File copying alone is not proof of runtime integration.
6. Report installed, preserved, pending and conflicting items separately.

## Ongoing Todoing task management

Use this mode when the project is already connected and the user asks to start,
update, review, complete, or cancel project work.

1. Do not rerun the installer for ordinary task work.
2. Verify `.manifest/manifest.yaml` and its checksum; require
   `components.todoing.enabled: true`.
3. Read both component switches. If OpenSpec is enabled, use the one-to-one
   Todoing/OpenSpec coordination procedure in `references/todoing-agent-workflow.md`.
   If OpenSpec is disabled, use standalone Todoing mode. Never treat enabled
   OpenSpec as a reason to stop or bypass Todoing task registration.
4. Verify the Project ID, existing Todoing config/store, and compatible binary.
   If bootstrap is incomplete, follow `references/todoing-bootstrap.md` only when
   the user explicitly asks to initialize Todoing.
5. Read and follow `references/todoing-agent-workflow.md` for every Todoing task
   lifecycle operation.
6. The Main Orchestrator is the sole Todoing API client. Role agents must not call
   Todoing, change task statuses, or receive lock tokens.
7. Only the user authorizes `backlog → ready` and cancellation. The Orchestrator
   records those decisions only after explicit user approval.
8. When both components are enabled, maintain exactly one Todoing task per
   OpenSpec change, reuse it by its external reference, and keep FR/checklist
   decomposition in `tasks.md` rather than creating duplicate tasks.
9. Do not copy this reference into project context files or enable any context-file
   switches. It is an agent skill reference, not a project template.

## Package

- Installer: scripts/install.sh
- Templates: templates/
- Todoing bootstrap contract: references/todoing-bootstrap.md
- Tests: tests/test-install.sh
