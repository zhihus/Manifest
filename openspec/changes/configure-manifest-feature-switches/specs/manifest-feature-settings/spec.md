# Manifest feature settings Specification

## Purpose

Define the project-level switches in `.manifest/manifest.yaml` and the
workflow behavior controlled by them.

## Requirements

### Requirement: Independent component switches

The configuration MUST define independent boolean switches for the Todoing
and OpenSpec components. Todoing MUST default to enabled and OpenSpec MUST default to disabled for newly initialized projects. Disabling one component MUST NOT implicitly disable or enable the
other.

#### Scenario: Initial component defaults

- **WHEN** a new project is initialized
- **THEN** Todoing and OpenSpec are both enabled in the generated configuration

#### Scenario: Todoing disabled independently

- **WHEN** Todoing is disabled and OpenSpec is enabled
- **THEN** the Orchestrator does not invoke Todoing or require its store
- **AND** OpenSpec remains available

#### Scenario: OpenSpec disabled independently

- **WHEN** OpenSpec is disabled and Todoing is enabled
- **THEN** the Orchestrator does not create, validate, or archive OpenSpec changes
- **AND** Todoing remains available without an OpenSpec reference requirement

### Requirement: Independent optional control switches

The configuration MUST define independent boolean switches for workflow
Preflight, Git hooks, Manifest Git checks, OpenSpec validation, tests,
the review gate, and other optional gates. For newly initialized projects,
all these switches MUST default to disabled.

#### Scenario: Optional controls disabled by default

- **WHEN** a new project is initialized
- **THEN** every optional control switch is `false`

#### Scenario: A single control is enabled

- **WHEN** one optional control is enabled and all other controls remain disabled
- **THEN** only that control is eligible to execute
- **AND** no other disabled control is invoked

#### Scenario: Disabled control is skipped

- **WHEN** a workflow reaches a disabled control
- **THEN** the Orchestrator skips its command, agent, and gate
- **AND** reports the control as `SKIPPED`, not `PASSED`

### Requirement: Configuration drives workflow execution

The Main Orchestrator MUST read and validate the configuration before starting
the workflow. Every optional stage MUST be guarded by its corresponding switch.
A missing, malformed, or ambiguous switch MUST fail closed for the affected
optional stage and be reported; it MUST NOT be interpreted as enabled.

#### Scenario: Invalid configuration

- **WHEN** a required switch is missing, malformed, or not boolean
- **THEN** the Orchestrator stops before executing the affected workflow stage
- **AND** reports the invalid key

#### Scenario: No disabled command is invoked

- **WHEN** all optional controls are disabled
- **THEN** no Preflight, Git hook/check, OpenSpec validation, test, review, or
  additional-gate command or agent is invoked

### Requirement: Mandatory integrity protections remain active

Configuration checksum verification, protection against overwriting an existing
configuration, additive reconnection, and mandatory installer safety
preconditions MUST remain active regardless of optional workflow switches. These protections MUST NOT be configurable off.

#### Scenario: Optional checks disabled but configuration tampered

- **WHEN** optional controls are disabled and the configuration checksum
  does not match
- **THEN** Manifest refuses to proceed and reports the integrity failure

#### Scenario: Installer safety precondition fails

- **WHEN** the installer is not in a Git work tree or cannot safely write
- **THEN** initialization stops without writing project files, regardless of
  workflow Preflight settings

### Requirement: Existing project configuration is preserved

Manifest MUST NOT rewrite existing `.manifest/manifest.yaml` files
automatically. This change applies defaults only to newly initialized projects.
Any migration of an existing configuration requires a separate explicit action.

#### Scenario: Existing configuration

- **WHEN** a project already has a valid `.manifest/manifest.yaml`
- **THEN** initialization preserves the configuration and checksum byte-identically
- **AND** may add only missing items selected by the existing settings

### Requirement: Todoing task identity matches the OpenSpec change

When both Todoing and OpenSpec are enabled, the Todoing task title MUST
exactly equal the OpenSpec change directory ID. The task MUST carry one
project-scoped `openspec.change` reference whose value is that same ID.
FR implementation tasks inside the change MUST NOT become separate Todoing
tasks.

#### Scenario: Matching task and change

- **WHEN** the Orchestrator creates a Todoing task for an OpenSpec change
- **THEN** the task title and `openspec.change` reference value exactly match
  the change directory ID

#### Scenario: Mismatched task title

- **WHEN** the Todoing task title differs from the OpenSpec change directory ID
- **THEN** the Orchestrator stops before approval or implementation and reports
  the mismatch

### Requirement: Context files have independent switches

The configuration MUST expose an independent boolean setting for each supported context file under `context_files.<id>.enabled`. Every context-file switch MUST default to false. The installer MUST install only files whose own switch is true and MUST never delete an existing file when a switch is false.

#### Scenario: Default context selection

- WHEN a new project is initialized without context-file selection
- THEN all context-file switches are false and no context templates are installed

#### Scenario: Single-file selection

- WHEN one context-file switch is true
- THEN only that file is eligible for installation

#### Scenario: Legacy config

- WHEN an existing valid config lacks context_files
- THEN it is preserved unchanged and context-file installation is skipped pending explicit migration
