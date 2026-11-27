# Manifest feature settings Specification

## Purpose

Define the project-level switches in `.manifest/manifest.yaml` and the
workflow behavior controlled by them.

## Requirements

### Requirement: Independent component switches

The configuration MUST define independent boolean switches for the Todoing
and OpenSpec components. Both MUST default to enabled for newly initialized
projects. Disabling one component MUST NOT implicitly disable or enable the
other.

#### Scenario: Both components enabled by default

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
configuration, refusal to reinitialize an initialized project, and mandatory
installer safety preconditions MUST remain active regardless of optional
workflow switches. These protections MUST NOT be configurable off.

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

- **WHEN** a project already has `.manifest/manifest.yaml`
- **THEN** initialization refuses reinitialization and leaves the configuration
  and checksum byte-identical
