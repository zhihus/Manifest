# Add standalone Manifest Init skill

## Why

Manifest has an initializer script but no standalone distributable connection skill. The existing initializer refuses projects that already contain .manifest/, so it cannot complete partial connections safely.

## What Changes

- Add a self-contained skills/manifest-init/ package with instructions, installer, templates, and tests.
- Restore corrupted root entry points as wrappers to the package.
- Make connection additive and idempotent: full baseline for new projects; only missing items for existing projects.
- Preserve existing files/configuration and stop on checksum or unsupported-schema errors.
- Add OpenSpec scaffolding without replacing existing configuration.
- Keep Todoing binary installation user-managed and bootstrap non-destructive.
- Align permanent connection specifications with the approved connected-project structure.
