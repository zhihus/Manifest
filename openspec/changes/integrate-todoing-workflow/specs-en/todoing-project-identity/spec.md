# Spec Delta

## Purpose

Defines the Project Identity mechanism for the Manifest–Todoing integration:
generation, validation, and protection of a stable Project ID stored in
`.manifest/project-id` and passed in every Todoing API request.

## ADDED Requirements

### Requirement: Project ID generation

The system SHALL generate a UUIDv4 Project ID and write it atomically to
`.manifest/project-id` when the file is absent and no store exists.

#### Scenario: First-time generation
- WHEN `.manifest/project-id` is absent and no Todoing store exists
- THEN the system generates a UUIDv4 and writes it atomically to
  `.manifest/project-id`

#### Scenario: File already present
- WHEN `.manifest/project-id` exists
- THEN the system uses its value and does not generate a new ID

### Requirement: Project ID validation

The system SHALL validate the Project ID against Todoing Project ID rules
(1–128 characters, no leading or trailing whitespace, no control characters)
on every integration start and, when a store exists, reconcile it with
`store.info`.

#### Scenario: Valid ID
- WHEN the Project ID passes Todoing validation and matches `store.info`
- THEN the integration proceeds

#### Scenario: Mismatch with store
- WHEN the Project ID does not match `store.info`
- THEN the system stops with `project_id_mismatch` diagnostics and does not
  reinitialize the store

### Requirement: Project ID absence handling

The system SHALL handle the absence of `.manifest/project-id` by generating a
new ID only when no store exists; when a store exists but the file is absent,
the system SHALL stop.

#### Scenario: Absent file, no store
- WHEN `.manifest/project-id` is absent and no store exists
- THEN the system generates a new UUIDv4

#### Scenario: Absent file, existing store
- WHEN `.manifest/project-id` is absent but a store exists
- THEN the system stops: the ID is unknown and the store is not
  reinitialized

### Requirement: Project ID protection

The system SHALL treat `.manifest/project-id` as immutable after creation: it
is never overwritten automatically. A change is possible only by explicit user
decision with store re-creation.

#### Scenario: No automatic overwrite
- WHEN the bootstrap flow runs and `.manifest/project-id` exists
- THEN the system does not overwrite the file

#### Scenario: Unauthorized change detected
- WHEN the Project ID in `.manifest/project-id` no longer matches
  `store.info`
- THEN the system detects the mismatch and stops