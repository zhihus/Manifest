## Purpose

Defines repeatable, non-destructive installation of the Guard core and the separately enabled ZCode plugin, including preservation of existing hooks and settings and safe failure on unsupported layouts.

## ADDED Requirements

### Requirement: Non-destructive install
The installer SHALL be repeatable and non-destructive for the Guard core: it MUST preserve existing hooks and settings via a managed dispatcher/chaining mechanism and MUST NOT silently replace `core.hooksPath`.

#### Scenario: Reinstall over existing install
- **WHEN** the installer runs on a machine where the Guard is already installed
- **THEN** existing user hooks remain chained and functional, and the managed dispatcher is updated in place

#### Scenario: Pre-existing hooksPath
- **WHEN** `core.hooksPath` already points to a non-managed location with existing hooks
- **THEN** the installer chains them instead of overwriting, or stops safely reporting the unsupported layout

### Requirement: Separate plugin enablement
The ZCode plugin (hooks, MCP broker) SHALL ship as an explicitly enabled plugin, not as project configuration; installation of core and enablement of the plugin are separate steps.

#### Scenario: Core installed without plugin
- **WHEN** only the core is installed and the plugin is not enabled
- **THEN** the core operates with Git-level enforcement only and documents that Harness-level interception is inactive

### Requirement: Safe failure and layout checks
The installer SHALL stop safely on unsupported Git layouts, and SHALL support reinstall, updates and Git Worktrees. Checksums of Guard files MUST be verifiable against an independently protected trusted reference.

#### Scenario: Unsupported layout
- **WHEN** the installer detects a Git configuration it cannot safely chain (e.g., exotic hooks dispatcher)
- **THEN** it aborts without changing any existing configuration and explains the incompatibility

#### Scenario: Worktree checkout
- **WHEN** the repository is used from a Git Worktree
- **THEN** Guard enforcement works in the worktree or is explicitly disabled with a clear warning, never silently inactive

### Requirement: No mass rollback
The system SHALL NOT perform mass rollback of changes. Reversal is limited to explicitly requested, specific, safely reversible operations.

#### Scenario: Recovery requested
- **WHEN** recovery of an interrupted authorization is triggered
- **THEN** only the specific authorized change is reconciled and unrelated history is untouched
