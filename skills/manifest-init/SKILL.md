---
name: manifest-init
description: Connect Manifest to a new or existing Git project. Adds only missing files and components without overwriting user data.
---

# Manifest Init

Use when the user asks to connect, initialize, install, or repair Manifest in a project.

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
- Seven optional controls default to false: workflow preflight, Git hooks/checks, OpenSpec validation, tests, review gate, additional gates.
- Mandatory integrity and installer safety checks are never switchable.
- temp/ must be excluded from Git; add the rule only if absent.
- Todoing's binary is installed/updated by the user. Never download it or initialize over an existing store/legacy data.

## Procedure

1. Inspect Git status and project structure. Identify existing Manifest files, OpenSpec state, Todoing binary/config/database/legacy tasks, hooks and local conventions.
2. Run scripts/install.sh --project <path>. For a new project, component defaults may be overridden with --todoing enabled|disabled and --openspec enabled|disabled. Select individual context files during first-time initialization with repeated `--context-file ID=enabled|disabled`. For an existing configuration, edit only the chosen `context_files.<id>.enabled` value and recalculate `.manifest/manifest.yaml.checksum`; installer overrides are rejected for existing configurations. Existing configurations are immutable under automatic initialization; legacy configurations without per-file settings are preserved and require a separate explicit migration. For a new connection, confirm project name, purpose and tracks before writing. Existing valid project metadata is not re-interviewed.
3. Review installed, preserved and pending report sections. Existing destinations are never overwritten.
4. If Todoing is enabled, follow references/todoing-bootstrap.md. If its binary is unavailable, report the prerequisite and stop Todoing-dependent workflow; do not silently disable it.
5. Validate the resulting connection. File copying alone is not proof of runtime integration.
6. Report installed, preserved, pending and conflicting items separately.

## Package

- Installer: scripts/install.sh
- Templates: templates/
- Todoing bootstrap contract: references/todoing-bootstrap.md
- Tests: tests/test-install.sh
