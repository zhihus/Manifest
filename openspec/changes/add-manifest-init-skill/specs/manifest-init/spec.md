# manifest-init Specification

## Purpose

Defines safe, repeatable Manifest connection for new, existing, and partially connected Git projects.

## Requirements

### Requirement: Additive and idempotent connection

The initializer MUST analyze the target project and add only missing Manifest components and mandatory context files. It MUST NOT overwrite, merge, archive, or delete existing user files automatically.

#### Scenario: New project

- WHEN the initializer runs in a Git project without Manifest files
- THEN it creates the Manifest configuration, all mandatory context files, and default OpenSpec scaffolding
- AND it reports every created item

#### Scenario: Partially connected project

- WHEN some Manifest files or components already exist
- THEN only missing items are created
- AND all existing files remain byte-identical

#### Scenario: Repeated initialization

- WHEN the initializer runs again after a successful connection
- THEN it makes no duplicate changes
- AND reports existing items as preserved

### Requirement: Existing configuration integrity

The initializer MUST verify the checksum and schema of an existing .manifest/manifest.yaml before any write. It MUST never rewrite the configuration or checksum automatically.

#### Scenario: Tampered configuration

- WHEN the checksum does not match
- THEN initialization stops before writing any project files

#### Scenario: Unsupported legacy configuration

- WHEN an existing configuration is not supported format_version 1
- THEN initialization stops and reports that explicit migration is required

### Requirement: Independent component configuration

New configurations MUST enable Todoing and OpenSpec independently by default and MUST disable all seven optional controls by default.

#### Scenario: Defaults

- WHEN a new configuration is created
- THEN components.todoing.enabled and components.openspec.enabled are true
- AND checks.workflow_preflight, git_hooks, git_checks, openspec_validation, tests, review_gate, and additional_gates are false

### Requirement: Todoing bootstrap is non-destructive

The initializer MUST NOT download or update the Todoing binary and MUST NOT initialize over an existing database or legacy data. Existing Todoing configuration MUST remain unchanged.

#### Scenario: Todoing unavailable

- WHEN the Todoing binary is unavailable
- THEN core Manifest connection may complete and Todoing is reported as pending

#### Scenario: Existing Todoing data

- WHEN a database, legacy tasks, or configuration already exists
- THEN the initializer preserves it and does not call store.init blindly

### Requirement: Connection report

Every completed run MUST report installed, preserved, pending, and conflicting items separately.
