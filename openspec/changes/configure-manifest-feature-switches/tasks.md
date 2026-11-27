## 1. Configuration generation

- [x] fr-1.1-write-feature-switches
  Update `scripts/manifest-init.sh` so newly initialized projects receive
  valid YAML containing project metadata, enabled Todoing/OpenSpec component
  switches, and all optional control switches disabled. Escape project names
  as valid YAML scalars. Keep the existing SHA-256 checksum sidecar behavior
  unchanged. Do not weaken installer Preflight or checksum protection.
  Stop: the generated config has the exact schema and defaults from
  `design.md`; checksum generation still covers the complete config bytes.
  Maps to scenarios: independent component switches; optional controls disabled

## 2. Workflow execution

- [x] fr-2.1-guard-workflow-stages
  Update `workflow/README.ru.md` so the Main Orchestrator validates the
  configuration once at startup and checks the matching switch before every
  optional component or control stage. Specify skip semantics, invalid-value
  handling, and mandatory integrity protections. Preserve Todoing API custody
  and OpenSpec linkage rules.
  Stop: every optional stage is explicitly gated and disabled stages are
  reported as SKIPPED without invoking commands or agents.
  Maps to scenarios: configuration drives workflow execution; disabled control is skipped

## 3. English documentation

- [x] fr-3.1-sync-english-runbook
  Translate the approved Russian workflow changes into
  `workflow/README.en.md` without changing the technical meaning.
  Stop: both language editions describe identical switches and execution rules.
  Maps to scenarios: configuration drives workflow execution

## 4. Regression coverage

- [x] fr-4.1-add-config-regressions
  Extend `scripts/test-manifest-init.sh` with assertions for the generated
  YAML keys/defaults and checksum coverage. Do not execute the test suite as
  part of this task.
  Stop: regression cases cover all component and control defaults plus
  tamper detection.
  Maps to scenarios: independent component switches; optional controls disabled; mandatory integrity protections

## Verification status

Implementation and regression-case authoring are complete. Tests and validation commands were intentionally not executed; local verification remains with the user after syncing `develop`.
