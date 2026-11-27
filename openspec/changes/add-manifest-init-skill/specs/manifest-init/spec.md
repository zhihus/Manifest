## MODIFIED Requirements

### Requirement: Init entry point performs the connection cycle

The system MUST provide one command that analyzes the project, obtains confirmation for new project metadata, validates safety and integrity, adds missing components, and produces a connection report.

#### Scenario: New project

- WHEN the command runs in a Git project without Manifest files and the user confirms the proposed metadata
- THEN the Manifest configuration and explicitly enabled component scaffolding and context files are created
- AND the final report lists every created item

#### Scenario: Connection cycle and report

- WHEN the user confirms the proposed metadata for a new project
- THEN the command validates the project before writing
- AND reports installed, preserved, pending, and conflicting items separately

### Requirement: Configuration is stable and never auto-overwritten

The system MUST preserve a valid existing configuration and checksum byte-for-byte. Existing .manifest/ does not block additive installation of missing files; it blocks only unsafe or unsupported configuration changes.

#### Scenario: Existing configuration with missing components

- WHEN a valid configuration exists and an independently enabled component is missing
- THEN the skill preserves the configuration and checksum byte-for-byte
- AND installs only the missing component without rewriting existing files

### Requirement: Final report is produced on every completed run

The system MUST report installed items, preserved existing items, pending external prerequisites, and conflicts separately.

#### Scenario: Report categories

- WHEN a connection run completes with a mixture of existing, newly installed, pending, and conflicting items
- THEN the final report places each item in its corresponding category
- AND does not report preserved or pending items as installed

## ADDED Requirements

### Requirement: Additive and idempotent connection

The initializer MUST add only missing Manifest files and components. It MUST NOT overwrite, merge, archive, or delete existing user files automatically.

#### Scenario: Existing project contains user files

- WHEN the skill connects a project that already contains user files and partially installed Manifest components
- THEN it creates only missing eligible items
- AND preserves every pre-existing file byte-for-byte

### Requirement: Todoing bootstrap remains non-destructive

The skill MUST NOT download the Todoing binary or initialize over an existing store or legacy task data.

#### Scenario: Existing Todoing data

- WHEN Todoing is enabled and an existing Todoing store or legacy task data is detected
- THEN the skill leaves that data and its configuration unchanged
- AND reports the existing installation without initializing over it
