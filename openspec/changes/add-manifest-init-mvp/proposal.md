# Proposal: add-manifest-init-mvp

## Why

MVP item 3 (`manifest-init`) has no implementation: connecting Manifest
to a project (analysis, interview, Preflight, installing context
files) is currently done manually. This is the first independently
implementable MVP stage — it depends only on Manifest Core and the
approved template set that already exist in the repository, and it
unblocks later stages (hooks installation, Todoing/OpenSpec
integration).

## What Changes

- New `manifest-init` Bash entry point (`scripts/manifest-init.sh`)
  implementing the MVP init cycle: project analysis, user interview,
  configuration creation, Preflight, template installation, final
  report.
- New working directory `.manifest/` in the project root with a
  separate configuration file; the configuration is stable and is not
  overwritten automatically; re-initialization is not provided;
  accidental-overwrite protection is mandatory (decisions of
  2026-11-22).
- Installation of context files from the single common MVP template
  with overwrite protection: missing files are added, existing files
  are reported as name conflicts, no automatic merging.
- Preflight gate: if any mandatory precondition fails, the
  installation does not start and the reason is reported.
- Not in this stage (later stages): Git hooks installation, Todoing
  integration, specialized templates, the Manifest file update
  process, archiving of disabled templates.

## Capabilities

### New Capabilities

- `manifest-init`: the initialization flow — project analysis, user
  interview, creation of the `.manifest` working directory and its
  stable configuration file, protection against accidental
  overwrite, refusal to re-initialize, final report.
- `preflight`: mandatory preconditions checked before any changes;
  on failure the installation does not start and the reason plus
  required actions are reported.
- `template-install`: installing context files from the single common
  MVP template with overwrite protection and conflict reporting.

### Modified Capabilities

- None. This change creates new capabilities only.
