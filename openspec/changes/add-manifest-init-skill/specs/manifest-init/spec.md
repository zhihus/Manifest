## MODIFIED Requirements

### Requirement: Init entry point performs the connection cycle

The system MUST provide one command that analyzes the project, confirms new metadata, validates integrity, adds missing items, and reports installed, preserved, and pending components.

### Requirement: Configuration is stable and never auto-overwritten

The system MUST preserve a valid existing configuration and checksum byte-for-byte. Existing .manifest/ does not block additive installation of missing files; it blocks only unsafe or unsupported configuration changes.

### Requirement: Final report is produced on every completed run

The system MUST report installed items, preserved existing items, pending external prerequisites, and conflicts separately.

## ADDED Requirements

### Requirement: Additive and idempotent connection

New projects receive the complete mandatory context and enabled component scaffolding. Existing projects receive only missing items. No existing file is automatically overwritten, merged, archived, or deleted.

### Requirement: Todoing bootstrap remains non-destructive

The skill MUST NOT download the Todoing binary or initialize over an existing store or legacy task data.
