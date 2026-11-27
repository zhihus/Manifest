# init-connection-scenarios Specification

## Purpose

Defines safe connection behavior for empty, non-empty, partially connected, and already connected projects.

## Requirements

### Requirement: New project receives the baseline

When the target is a Git project without Manifest components, the initializer MUST create the mandatory context files, .manifest/manifest.yaml, its checksum, and default OpenSpec scaffolding when enabled.

#### Scenario: Fresh project

- WHEN initialization runs in a new Git project
- THEN the complete mandatory context baseline is installed
- AND component switches and optional control defaults are written as specified
- AND optional Git hooks are not activated while the git_hooks switch is false

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

#### Scenario: Name conflict

- WHEN a target path already exists
- THEN the existing item is preserved and reported

### Requirement: Subagent temp guidance is handled explicitly

When .zcode/agents/*.md definitions exist, the connector MUST detect whether the required temp boilerplate is present. Missing guidance is reported as pending and MUST NOT be inserted into existing agent files without explicit user approval.

#### Scenario: Project has agents

- WHEN agent definitions exist and lack the temp boilerplate
- THEN the connector reports the affected paths and requests approval before modifying them

### Requirement: Distribution excludes development infrastructure

The distributable skill MUST NOT contain Manifest repository verification scripts, Git hooks, or development-only infrastructure.

#### Scenario: Distribution contents

- WHEN the package is inspected
- THEN it contains only its instructions, installer, templates, references, and tests
- AND it does not contain scripts/verify.sh or scripts/hooks/
