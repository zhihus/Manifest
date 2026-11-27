# init-connection-scenarios Specification

## Purpose

Defines safe connection behavior for empty, non-empty, partially connected, and already connected projects.

## Requirements

### Requirement: New project receives the baseline

When the target is a Git project without Manifest components, the initializer MUST create mandatory context files, .manifest/manifest.yaml, its checksum, and default OpenSpec scaffolding.

#### Scenario: Fresh project

- WHEN initialization runs in a new Git project
- THEN the complete mandatory baseline is installed
- AND component switches and optional control defaults are written as specified

### Requirement: Existing project is augmented without replacement

When the project already contains user files or some Manifest components, initialization MUST add only missing components and MUST preserve existing content byte-for-byte.

#### Scenario: Foreign files

- WHEN unrelated user files exist
- THEN they remain unchanged

#### Scenario: Partial connection

- WHEN some mandatory context files, .manifest/, or OpenSpec configuration already exist
- THEN only missing items are added
- AND existing files/configuration are preserved

### Requirement: Existing configuration is immutable

A valid existing .manifest/manifest.yaml and checksum MUST remain byte-identical. An invalid checksum or unsupported schema MUST stop initialization before any write.

### Requirement: No automatic conflict resolution

The initializer MUST NOT archive, overwrite, merge, or delete conflicting files. It MUST report them for explicit user resolution.

### Requirement: Distribution excludes development infrastructure

The distributable skill MUST NOT include repository verification scripts, Git hooks, or development-only infrastructure.
