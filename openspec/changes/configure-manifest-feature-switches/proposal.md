# Configure Manifest feature switches

## Why

Manifest currently stores only project metadata in `.manifest/manifest.yaml`.
The workflow has no authoritative, machine-readable way to enable Todoing and
OpenSpec independently or to disable optional checks. As a result, documented
workflow stages can still run when the user intends to defer them.

## What Changes

- Extend the generated Manifest configuration with independent component and
  control switches.
- Enable Todoing and OpenSpec by default.
- Disable optional workflow checks by default for this rollout.
- Make the Main Orchestrator branch explicitly on each switch and report skipped
  stages without treating them as passed.
- Preserve mandatory configuration-integrity and installer-safety protections.

## Impact

- Affects `scripts/manifest-init.sh`, the Manifest workflow runbook, and the
  `manifest-init` OpenSpec capability.
- Existing initialized projects are not rewritten or migrated automatically.
