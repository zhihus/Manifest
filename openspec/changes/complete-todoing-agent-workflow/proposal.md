# Proposal: Complete Todoing Agent Workflow

## Why

Manifest documents the Todoing lifecycle primarily as a companion to OpenSpec. When
Todoing is enabled and OpenSpec is disabled, the runbook says tasks can be managed
without OpenSpec references but does not define the agent's complete task-management
procedure. The current acceptance suite also exercises only the combined
Todoing/OpenSpec path.

The runbook must support Todoing as an independent task manager and must identify
the exact Todoing API build required by the advanced integration operations.

## What Changes

- Define task discovery, duplicate avoidance, task creation, user approval, execution,
  review, completion, cancellation, and recovery when OpenSpec is disabled.
- Keep one Todoing task per independently meaningful outcome; implementation steps
  remain inside the task rather than becoming duplicate tasks.
- Pin the compatible Todoing API source baseline and correct the documented CLI
  invocation.
- Add an isolated acceptance scenario that completes a Todoing task without an
  OpenSpec directory or OpenSpec commands.

## Capabilities

### Added

- Standalone Todoing task lifecycle without OpenSpec.
- Explicit compatibility baseline for the advanced Todoing API operations.
- Acceptance coverage for the Todoing-only lifecycle.
