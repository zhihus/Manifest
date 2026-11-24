# connected-project-migration Specification

## Purpose

Defines a controlled, non-destructive migration process for existing repositories that are already registered or intended to be connected to Manifest.

## Requirements

### Requirement: Migration begins with a read-only inventory

The migration MUST establish a current read-only baseline before changing the target repository.

#### Scenario: Existing repository has drifted since its prior audit
- **WHEN** the migration starts and a previous audit is available
- **THEN** the migration rechecks Git state, project files, ignore rules, OpenSpec state, Manifest artifacts, and Todoing state
- **AND** records material differences
- **AND** performs no target-project mutation during the inventory

### Requirement: Existing Git history is preserved

The migration MUST preserve the existing commit graph and MUST NOT rewrite history.

#### Scenario: Project has local commits and no remote
- **WHEN** the inventory finds local commits without a remote or upstream
- **THEN** the migration reports the absence of remote backup and synchronization
- **AND** presents remote strategy options to the user
- **AND** does not create a remote, add a remote, push, reset, squash, or force-push without separate explicit approval

### Requirement: OpenSpec data is reviewed before Git tracking changes

The migration MUST inspect ignore rules and OpenSpec contents before changing whether OpenSpec files are tracked by Git.

#### Scenario: OpenSpec directory is ignored
- **WHEN** OpenSpec files are excluded by Git ignore rules
- **THEN** the migration identifies the exact ignore rule and enumerates the affected files
- **AND** proposes an explicit tracking scope and exclusions
- **AND** does not force-add or stage OpenSpec files before user approval

### Requirement: OpenSpec changes are not automatically archived

The migration MUST preserve active and archived OpenSpec records and MUST NOT archive completed changes as a side effect of connection setup.

#### Scenario: Completed change has not been archived
- **WHEN** a completed but unarchived change is discovered
- **THEN** the migration assesses its archive prerequisites and dependencies
- **AND** reports whether it is ready, blocked, or requires review
- **AND** leaves it unchanged until a separate approved archive operation

### Requirement: Existing project files are never silently overwritten

The migration MUST compare proposed Manifest artifacts with existing target files and MUST preserve existing project-specific content unless a user-approved reconciliation says otherwise.

#### Scenario: Distributed file conflicts with an existing project file
- **WHEN** a Manifest distribution file has a different destination file already present
- **THEN** the migration produces a diff and classifies the conflict
- **AND** does not overwrite the destination automatically

### Requirement: Git hooks are activated only after verification and approval

The migration MUST verify hook files before configuring Git to execute them.

#### Scenario: Hook directory exists but is incomplete
- **WHEN** the hook directory is missing one or more required hooks or validation fails
- **THEN** the migration does not set or enable the incomplete hook configuration
- **AND** reports the missing or failed artifacts

### Requirement: Project Identity is stable and non-destructive

The migration MUST create a Project ID only when none exists and MUST NOT replace an existing valid ID automatically.

#### Scenario: Valid Project ID already exists
- **WHEN** the migration finds an existing valid Project ID
- **THEN** it reuses and verifies that value
- **AND** does not generate or write a replacement

### Requirement: Todoing bootstrap uses the local CLI and preserves existing data

The migration MUST use the supported local Todoing CLI JSON API and MUST inspect existing Todoing data before bootstrap.

#### Scenario: Todoing is unavailable or legacy data exists
- **WHEN** the Todoing binary is unavailable, or legacy/config/store data requires a separate migration
- **THEN** the bootstrap stops without creating or overwriting Todoing data
- **AND** reports the exact prerequisite or migration decision required

### Requirement: Connection status reflects verified installation

The connected-project registry MUST NOT represent an incomplete installation as fully active.

#### Scenario: Required connection checks have not passed
- **WHEN** one or more required Manifest connection checks remain failed or blocked
- **THEN** the migration does not mark the project fully active
- **AND** reports the remaining checks and blockers
