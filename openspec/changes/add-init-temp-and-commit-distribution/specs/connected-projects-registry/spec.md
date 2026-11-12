# Spec Delta

## Purpose

The connected-projects-registry capability gives the Manifest
framework a single registry of connected projects: what is connected,
where it lives, on which framework version, and whether it is active.

## ADDED Requirements

### Requirement: registry file and entry format

The registry MUST live at `workflow/connected-projects.md` in the
Manifest project. Each connected project MUST have exactly one entry
containing: project name (kebab-case), path to the project folder,
connection date (ISO date), framework version at connection time, and
status (`active` or `archived`).

#### Scenario: entry after successful connection

- **WHEN** manifest-init connects a project successfully
- **THEN** a new entry with name, path, date, version and
  `status: active` appears in the registry

### Requirement: registry write is an agent step

The registry entry MUST be written by the agent running the
manifest-init skill, not by the init script. If the Manifest project
is not found, the agent MUST report it and continue without writing —
project connection MUST NOT fail because of the registry.

#### Scenario: Manifest not found

- **WHEN** the Manifest project folder is not reachable during init
- **THEN** the agent reports the missing registry write to the user
  and the connection itself still succeeds

### Requirement: status transitions

A project removed or retired MUST be marked `archived` (not deleted
from the registry). A moved project MUST have its path updated.

#### Scenario: archiving a project

- **WHEN** the user says a project is no longer connected
- **THEN** the entry's status changes to `archived`; the entry stays
