# Skill distribution Specification

## Purpose

Define how Manifest distributes standalone agent skills without absorbing them into the Manifest core.

## Requirements

### Requirement: Skills remain independent components

Manifest MUST distribute each skill as a self-contained component with its own implementation, license, third-party notices, dependencies, and lifecycle.

#### Scenario: Skill package is distributed

- **WHEN** a skill is included in the Manifest distribution
- **THEN** its complete package is stored under `skills/<skill-id>/`
- **AND** its implementation is not merged into Manifest core
- **AND** its license and third-party notices are preserved

### Requirement: Windows installation is explicit and non-destructive

The system MUST provide a Windows PowerShell installer that copies a selected skill into an explicitly supplied agent skills directory, verifies the staged copy, and refuses to overwrite an existing destination.

#### Scenario: New skill installation

- **WHEN** the user runs the installer with a valid skills directory
- **THEN** the complete skill is copied to `<TargetRoot>/<skill-id>/`
- **AND** the staged file list and SHA-256 hashes match the source package
- **AND** the completed staging directory is moved into place only after verification

#### Scenario: Existing skill destination

- **WHEN** the destination skill directory already exists
- **THEN** installation stops without modifying or deleting the existing directory

### Requirement: Runtime bootstrap requires separate approval

Manifest MUST NOT run a skill bootstrap automatically during project connection or skill copying. A bootstrap that downloads runtimes or external components MUST expose its plan first and require a separate explicit user action before downloading.

#### Scenario: First Windows bootstrap invocation

- **WHEN** the user runs `bootstrap.ps1` without an installation mode
- **THEN** the component plan is displayed
- **AND** the command exits with the approval-required code without downloading components

### Requirement: Windows validation is automated

The repository MUST run Windows-specific validation for the installer, bootstrap entry point, and bootstrap regression tests.

#### Scenario: Windows CI

- **WHEN** skill distribution or installer files change
- **THEN** GitHub Actions runs on a Windows runner
- **AND** validates PowerShell syntax, safe installation, overwrite refusal, bootstrap approval gating, and Python regression tests
