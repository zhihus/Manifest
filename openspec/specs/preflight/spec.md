# preflight Specification

## Purpose
Mandatory preconditions checked before any change is made to the
project during Manifest initialization; on failure the installation
does not start and the reason plus required actions are reported.

## Requirements

### Requirement: Preflight runs before any change
The system MUST run all Preflight checks before creating or modifying anything in the project.

The system runs all Preflight checks before creating or modifying
anything in the project.

#### Scenario: Check happens before write
- **WHEN** the command runs
- **THEN** no file inside the project is created or modified before all mandatory Preflight checks have completed

### Requirement: Mandatory preconditions
The system MUST verify at minimum: Git availability, Git repository, write permission in the project root, absence of an existing .manifest directory, and availability of the template source directory.

The system verifies at minimum: Git is available in the project,
the current directory is a Git repository, write permission in the
project root, absence of an existing .manifest/ directory, and
availability of the template source directory.

#### Scenario: Not a Git repository
- **WHEN** Preflight runs outside a Git repository
- **THEN** the command reports the failed precondition
- **AND** names the required action (initialize Git first)
- **AND** exits non-zero without creating .manifest/

#### Scenario: Manifest already initialized
- **WHEN** a .manifest/ directory already exists
- **THEN** the command reports that the project is already initialized and exits non-zero

#### Scenario: Template source unavailable
- **WHEN** the configured template source directory cannot be read
- **THEN** the command reports the missing source and exits non-zero without writing anything

### Requirement: Failure reports reason and required actions
Every Preflight failure MUST produce a message stating which check failed, why, and what the user must do.

Every Preflight failure produces a message stating which check
failed, why, and what the user must do.

#### Scenario: Multiple failures
- **WHEN** more than one mandatory precondition fails
- **THEN** all failures are listed in one report, not only the first

### Requirement: Diagnostics only, no automatic fixing
Preflight MUST NOT modify the project to fix detected problems; it only diagnoses and reports.

Preflight does not modify the project to fix detected problems; it
only diagnoses and reports.

#### Scenario: Missing write permission
- **WHEN** the project root is not writable
- **THEN** the command reports the problem and exits non-zero
- **AND** no attempt is made to change permissions or create directories

### Requirement: Perl rendering capability is verified before installation
The preflight MUST verify that Perl is available and can execute a trivial program before the installer writes project files, because Perl is required by the template renderer.

#### Scenario: Perl is unavailable
- **WHEN** Perl is missing or cannot execute a trivial program
- **THEN** preflight fails with an actionable reason
- **AND** no project files are written

### Requirement: SHA-256 capability is verified portably
The preflight MUST verify that a working SHA-256 tool is available without assuming a specific binary name. sha256sum or an equivalent such as shasum -a 256 is accepted, and the detected tool is used consistently for the checksum guard.

The stored checksum records which tool produced it; re-verification
uses the same tool or an equivalent byte-identical SHA-256 algorithm.

#### Scenario: macOS without sha256sum
- **WHEN** the project runs on a platform where sha256sum is absent but shasum -a 256 is available
- **THEN** preflight accepts the environment
- **AND** the checksum guard works with the detected tool

#### Scenario: No SHA-256 tool at all
- **WHEN** no working SHA-256 tool is found
- **THEN** preflight fails with the reason and required action
- **AND** nothing is written to the project
