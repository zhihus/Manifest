# Proposal

## Why

The repository `C:\WorkProjects\vstrecha-raytec` is listed as an active Manifest-connected project, but the read-only audit on 2026-11-24 found that the connection is incomplete and several project-level decisions are unresolved.

The project has an existing Git history (189 local commits), no remote or upstream, an existing OpenSpec workspace excluded by `.gitignore`, and substantial project-specific context and process documentation. Manifest installation is partial: `.manifest/hooks/` exists but is empty; the required hooks, validation script, and Project ID are absent; `core.hooksPath` is unset; and the existing `commit-rules.md` differs from the current Manifest distribution. Todoing is not initialized.

A controlled migration is required. A generic fresh-project initializer is insufficient because it could overwrite or hide existing project state.

## What Changes

- Define a staged, non-destructive migration procedure for the existing project, covering preparation, approval, execution, and verification for every stage.
- Require a fresh pre-migration inventory and separate, explicit, narrowly scoped user approval immediately before every migration stage that mutates the target repository; approval never carries over to a later stage.
- Preserve the existing Git commit graph; prohibit history rewriting, reset, force-push, and implicit remote creation.
- Resolve the Git remote/upstream strategy before any push or remote synchronization.
- Inspect the exact ignore rules and OpenSpec contents before changing Git tracking; execute only the exact approved tracking changes.
- Preserve all active and archived OpenSpec changes; do not auto-archive completed changes or repair archive blockers during bootstrap.
- Reconcile Manifest installation artifacts with existing project files by diff, apply only approved file changes, and handle hooks as a separately gated operation.
- Create the Manifest Project ID and Todoing configuration/store only after their prerequisites and user decisions are satisfied.
- Verify the final connection and report unresolved items without claiming a complete connection prematurely.

## Capabilities

- `connected-project-migration` — controlled migration of an existing repository into the approved Manifest connected-project structure.

## Out of Scope

- Changing application code or business behavior in `vstrecha-raytec`.
- Automatically restructuring or renaming existing project documentation.
- Automatically archiving, deleting, rewriting, or migrating OpenSpec changes/specifications.
- Choosing or creating a Git hosting repository, adding a remote, pushing commits, or rewriting Git history without separate explicit approval.
- Installing or upgrading the Todoing binary.
- Changing Todoing's API or adding a network service; Todoing is invoked through its local CLI JSON API.
- Implementing the migration in the target project as part of this specification change.
