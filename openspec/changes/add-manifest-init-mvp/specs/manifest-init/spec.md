# Spec Delta: manifest-init

## Purpose

Governs the Manifest initialization flow: analyzing the project,
interviewing the user, creating the stable `.manifest` working
directory and configuration, refusing re-initialization, and
producing the final report.

## ADDED Requirements

### Requirement: Init entry point performs the full MVP cycle
The system MUST provide a single command that runs: project analysis, user interview, configuration creation, Preflight, template installation, and a final report.

The system provides a single command that runs: project analysis,
user interview, configuration creation, Preflight, template
installation, and a final report.

#### Scenario: Successful init of a Git project without context files

- **WHEN** the command runs in a Git project with no `.manifest/`
  and no existing context files, the user answers the interview, and
  all Preflight checks pass
- **THEN** the `.manifest/` working directory and its configuration
  file are created, the template files are installed, and the final
  report lists every installed file
- **AND** the command exits 0

### Requirement: Working directory is .manifest with a separate config
The system MUST store Manifest project settings in one dedicated configuration file directly under the .manifest directory in the project root and use no other settings locations.

The system stores Manifest project settings in a dedicated
configuration file inside the `.manifest` directory in the project
root; no other settings locations are used.

#### Scenario: Config location

- **WHEN** initialization completes
- **THEN** project settings exist as one configuration file directly
  under `.manifest/`
- **AND** no settings are written outside `.manifest/` by the init
  flow

### Requirement: Configuration is stable and never auto-overwritten
The system MUST never overwrite or rewrite the configuration file automatically after creation.

The system never overwrites or rewrites the configuration file
automatically after creation.

#### Scenario: Re-run against an initialized project

- **WHEN** the command runs in a project where `.manifest/` already
  exists
- **THEN** no configuration or working-directory content is modified
- **AND** the command reports that re-initialization is not provided
  and exits non-zero

### Requirement: Protection against accidental configuration overwrite
The system MUST maintain a protection mechanism over the configuration file and MUST verify it before any write attempt into .manifest.

The system maintains a protection mechanism over the configuration
file and verifies it before any write attempt into `.manifest/`.

#### Scenario: Modified configuration detected

- **WHEN** the configuration file content no longer matches the
  protection record created at init time
- **THEN** the command refuses to write anything into `.manifest/`
- **AND** reports the protection failure explicitly

### Requirement: Interview determines the project configuration
The system MUST derive the project configuration from project analysis plus an interview with the user, and MUST get user confirmation before writing anything.

The system derives the project configuration (project name; tracks
code/documentation/mixed as informational MVP flags) from project
analysis plus an interview with the user; the user confirms the
result before anything is written.

#### Scenario: User adjusts proposed configuration

- **WHEN** during the interview the user changes a proposed value
- **THEN** the confirmed value is written to the configuration file
- **AND** the unconfirmed proposal is not persisted anywhere

### Requirement: Final report is produced on every completed run
The system MUST print a report listing created files, installed template files, and skipped conflicts on every completed run.

The system prints a report listing: created files, installed template
files, skipped conflicts (if any), and skipped items, so an
orchestrator or user can verify the result without re-inspecting the
disk.

#### Scenario: Report after install with one conflict

- **WHEN** initialization completes with one existing target file
  skipped
- **THEN** the report contains that file path marked as a conflict
- **AND** the report contains the list of installed files
