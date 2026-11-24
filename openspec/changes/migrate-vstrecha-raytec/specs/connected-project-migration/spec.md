# connected-project-migration Specification

## Purpose

Defines a controlled, non-destructive migration process for existing repositories registered or intended to be connected to Manifest.

## ADDED Requirements

### Requirement: Migration starts with a read-only inventory

The migration MUST establish a current read-only baseline before changing the target repository.

#### Scenario: Existing repository has drifted
- **WHEN** migration starts and a previous audit exists
- **THEN** Git state, project files, ignore rules, OpenSpec state, Manifest artifacts, and Todoing state are rechecked
- **AND** material differences are recorded
- **AND** no target-project mutation occurs during inventory

### Requirement: Existing Git history is preserved

The migration MUST preserve the existing commit graph and MUST NOT rewrite history.

#### Scenario: Local commits exist without a remote
- **WHEN** inventory finds local commits and no remote/upstream
- **THEN** the migration reports the lack of remote backup and synchronization
- **AND** presents remote strategy options to the user
- **AND** does not create a remote, add a remote, push, reset, squash, or force-push without separate explicit approval

### Requirement: OpenSpec is reviewed before Git tracking changes

The migration MUST inspect ignore rules and OpenSpec contents before changing their Git tracking state.

#### Scenario: OpenSpec is ignored
- **WHEN** OpenSpec files are excluded by Git ignore rules
- **THEN** the exact ignore rule and affected files are identified
- **AND** an explicit tracking scope and exclusions are proposed
- **AND** files are not force-added or staged before user approval

### Requirement: OpenSpec changes are not automatically archived

The migration MUST preserve active and archived OpenSpec records and MUST NOT archive completed changes as a side effect of connection setup.

#### Scenario: Completed change is not archived
- **WHEN** a completed but unarchived change is found
- **THEN** its archive prerequisites and dependencies are assessed
- **AND** it is reported as ready, blocked, or requiring review
- **AND** it remains unchanged until a separate approved archive operation

### Requirement: Existing project files are not silently overwritten

The migration MUST compare proposed Manifest artifacts with existing files and preserve project-specific content unless a user-approved reconciliation specifies otherwise.

#### Scenario: Manifest artifact conflicts with an existing file
- **WHEN** a destination file exists with different content
- **THEN** a diff and conflict classification are produced
- **AND** the destination is not overwritten automatically

### Requirement: Hooks are activated only after verification and approval

The migration MUST verify hook files before configuring Git to execute them.

#### Scenario: Hook installation is incomplete
- **WHEN** a required hook is missing or validation fails
- **THEN** the incomplete hook configuration is not activated
- **AND** missing or failed artifacts are reported

### Requirement: Project Identity is stable

The migration MUST create a Project ID only when none exists and MUST NOT replace an existing valid ID automatically.

#### Scenario: A valid Project ID already exists
- **WHEN** the migration finds an existing valid Project ID
- **THEN** it reuses and verifies that value
- **AND** does not generate or write a replacement

### Requirement: Todoing bootstrap uses the local CLI and preserves data

The migration MUST use the supported local Todoing CLI JSON API and inspect existing Todoing data before bootstrap.

#### Scenario: Todoing is unavailable or legacy data exists
- **WHEN** the binary is unavailable or existing data requires a separate migration
- **THEN** bootstrap stops without creating or overwriting Todoing data
- **AND** reports the exact prerequisite or decision required

### Requirement: Connection status reflects verified installation

The connected-project registry MUST NOT represent an incomplete installation as fully active.

#### Scenario: Required connection checks have not passed
- **WHEN** one or more required checks remain failed or blocked
- **THEN** the project is not marked fully active
- **AND** remaining checks and blockers are reported
