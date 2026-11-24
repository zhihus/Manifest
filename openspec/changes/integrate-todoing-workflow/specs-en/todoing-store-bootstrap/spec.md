# Spec Delta

## Purpose

Defines the Todoing store bootstrap procedure for Manifest: checking binary
availability, writing the configuration without overwrite, calling
`store.init` only for a new store, and refusing to overwrite legacy data and
an existing store.

## ADDED Requirements

### Requirement: Todoing availability check

The system SHALL verify that the `todoing` binary is on PATH and that
`todoing api --json` responds. Todoing installation is performed by the user;
Manifest does not download or update the binary.

#### Scenario: Todoing available
- WHEN `todoing` is on PATH and `todoing api --json` responds
- THEN the bootstrap continues

#### Scenario: Todoing unavailable
- WHEN `todoing` is unavailable or does not respond
- THEN the bootstrap stops with diagnostics; installation is performed by the
  user separately

### Requirement: Configuration without overwrite

The system SHALL create `.todoing/` and write the recommended `config.toml`
atomically only when the file is not yet present. An existing `config.toml`
is validated and preserved; on incompatibility the bootstrap stops.

#### Scenario: Configuration absent
- WHEN `.todoing/config.toml` is absent
- THEN the system atomically writes the recommended configuration

#### Scenario: Configuration present
- WHEN `.todoing/config.toml` exists
- THEN the system validates it (statuses, outcome mapping, transitions) and
  does not overwrite it

#### Scenario: Incompatible configuration
- WHEN the existing `config.toml` is incompatible
- THEN the bootstrap stops with diagnostics; the file is not overwritten

### Requirement: Store initialization

The system SHALL call `store.init` with the Project ID from
`.manifest/project-id`. The operation creates a new store only when the
database does not exist.

#### Scenario: New store
- WHEN `todoing.db` does not exist
- THEN `store.init` creates a new store

#### Scenario: Store already exists
- WHEN `todoing.db` exists
- THEN `store.init` returns `store_already_initialized`; the system does not
  reinitialize the store

#### Scenario: Legacy data
- WHEN legacy Markdown tasks (`.todoing/tasks/*.md`) or `index.json` are
  present
- THEN `store.init` returns `migration_required`; the system does not perform
  `store.init` and offers a separate migration procedure

### Requirement: Store verification

The system SHALL verify the initialization result through `store.info` and
`store.verify`.

#### Scenario: Store initialized
- WHEN `store.info` and `store.verify` confirm correctness
- THEN the bootstrap completes successfully

#### Scenario: Store incorrect
- WHEN `store.info` or `store.verify` detects a problem
- THEN the bootstrap stops with diagnostics