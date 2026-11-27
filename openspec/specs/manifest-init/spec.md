# manifest-init Specification

## Purpose

Defines safe, repeatable Manifest connection for new, existing, and partially connected Git projects.

## Requirements

### Requirement: Init entry point performs the connection cycle

The system MUST provide one command that analyzes the project, obtains confirmation for new project metadata, validates safety and integrity, adds missing components, and produces a connection report.

#### Scenario: New project

- WHEN the command runs in a Git project without Manifest files and the user confirms the proposed metadata
- THEN the Manifest configuration and explicitly enabled component scaffolding and context files are created
- AND the final report lists every created item

### Requirement: Working directory and configuration location

The system MUST store project settings in the single configuration file .manifest/manifest.yaml in the project root and MUST NOT create parallel Manifest settings files.

#### Scenario: Configuration location

- WHEN initialization completes
- THEN project settings exist in .manifest/manifest.yaml with a matching checksum sidecar

### Requirement: Additive and idempotent connection

The initializer MUST add only missing Manifest files and components. It MUST NOT overwrite, merge, archive, or delete existing user files automatically.

#### Scenario: Partially connected project

- WHEN some Manifest files or components already exist
- THEN only missing items are created
- AND all existing files remain byte-identical

#### Scenario: Repeated initialization

- WHEN initialization runs again against an already connected project
- THEN it preserves existing files and settings and creates no duplicates

### Requirement: Existing configuration is immutable

The system MUST never rewrite an existing configuration or checksum automatically. A valid existing configuration is preserved while missing independent components may be added.

#### Scenario: Existing valid configuration

- WHEN initialization runs against a valid existing .manifest/manifest.yaml
- THEN its configuration and checksum remain byte-identical
- AND only missing project artifacts may be added

### Requirement: Configuration integrity is mandatory

The system MUST verify the configuration checksum and required schema before any project write.

#### Scenario: Modified configuration detected

- WHEN the checksum does not match, is missing, or is orphaned
- THEN initialization stops before writing project files and reports the integrity failure

#### Scenario: Unsupported configuration

- WHEN the existing configuration is not supported format_version 1 or a required switch is malformed
- THEN initialization stops and requires an explicit migration or repair decision

### Requirement: Interview determines new project metadata

For a project without an existing Manifest configuration, the system MUST derive the proposed project name and tracks from project analysis and obtain user confirmation before writing. Existing valid project metadata MUST NOT be re-interviewed or changed.

#### Scenario: User adjusts proposed metadata

- WHEN the user changes a proposed value
- THEN the confirmed value is used for newly generated files and configuration

### Requirement: Component defaults and independence

New configuration MUST enable Todoing and disable OpenSpec by default. Both component switches remain independent. It MUST define a separate boolean switch for each supported context file, all disabled by default. All seven optional controls remain disabled by default.

#### Scenario: Default switches

- WHEN a new configuration is generated without component overrides
- THEN Todoing is enabled, OpenSpec is disabled, every context-file switch is disabled, and workflow_preflight, git_hooks, git_checks, openspec_validation, tests, review_gate, and additional_gates are disabled

### Requirement: Todoing bootstrap is non-destructive

Manifest MUST NOT download or update the Todoing binary and MUST NOT initialize over an existing database or legacy data. Existing Todoing configuration MUST remain unchanged.

#### Scenario: Todoing unavailable

- WHEN Todoing is enabled but its binary is unavailable
- THEN core connection may complete and Todoing is reported as pending

### Requirement: Connection report

Every completed run MUST report installed, preserved, pending, and conflicting items separately.

### Requirement: Install-time dependencies are declared

The installer MUST use only external binaries declared in the external dependency register, including Bash, Git, Perl, SHA-256 tooling, mktemp, awk, grep, sed, find, ln, chmod, and date where invoked.

#### Scenario: Registered dependencies

- WHEN the installer runs
- THEN every external binary it invokes is documented with its purpose, scope, and detection method

### Requirement: Context files are individually selectable

The configuration MUST define a separate boolean setting for every supported context file under `context_files.<id>.enabled`. The installer MUST create a context file only when its own setting is true. Disabling a setting MUST NOT delete an existing file.

#### Scenario: All context files disabled by default

- WHEN a new project is connected without context-file selections
- THEN every context-file switch is false
- AND no context template is installed

#### Scenario: One context file enabled

- WHEN exactly one context-file switch is true
- THEN only the corresponding missing file is installed
- AND all other context files remain untouched

#### Scenario: Existing file with enabled switch

- WHEN a context-file switch is true and its target path already exists
- THEN the existing file is preserved byte-for-byte and reported

#### Scenario: Legacy configuration without per-file settings

- WHEN an existing valid configuration has no context_files section
- THEN the configuration remains unchanged
- AND no context files are installed
- AND the report states that explicit migration is required
