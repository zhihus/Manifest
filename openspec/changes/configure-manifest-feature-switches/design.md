# Design: configure-manifest-feature-switches

## Decisions

1. Keep `.manifest/manifest.yaml` as the sole Manifest project configuration.
2. Emit valid YAML with `format_version: 1`, a `project` section,
   `components` switches, and `checks` switches.
3. Default `components.todoing.enabled` to `true` and
   `components.openspec.enabled` to `false`.
4. Add independent `context_files.<id>.enabled` switches for every supported context file; all default to `false`.
5. Default every optional control under `checks` to `false:
   `workflow_preflight`, `git_hooks`, `git_checks`,
   `openspec_validation`, `tests`, `review_gate`, and
   `additional_gates`.
6. Do not add a switch for checksum verification or installer safety. They are
   mandatory integrity protections, not optional workflow gates.
7. Treat installer Preflight as distinct from the optional workflow Preflight.
   The installer checks remain mandatory because they protect writes during
   initialization.
8. Existing project configurations are immutable under automatic initialization.
   No in-place migration is included.

## Configuration shape

```yaml
format_version: 1
project:
  name: "Example"
  tracks: code
  created: "2026-11-27"
components:
  todoing:
    enabled: true
  openspec:
    enabled: false
context_files:
  agents:
    enabled: false
  llm-navigation:
    enabled: false
  versioning:
    enabled: false
  releases:
    enabled: false
  logging:
    enabled: false
  code-rules:
    enabled: false
  test-rules:
    enabled: false
  commit-rules:
    enabled: false
  version:
    enabled: false
  llmignore:
    enabled: false
checks:
  workflow_preflight:
    enabled: false
  git_hooks:
    enabled: false
  git_checks:
    enabled: false
  openspec_validation:
    enabled: false
  tests:
    enabled: false
  review_gate:
    enabled: false
  additional_gates:
    enabled: false
```

The Orchestrator reads these values at workflow start and before each guarded
stage. Disabled stages are not launched and are recorded as skipped. Component
switches control whether the corresponding component is used at all.

## Scope boundary

Manifest is a documentation-led framework. The Orchestrator is the Main Agent,
not a new executable service. The workflow runbook is therefore the runtime
policy implementation; the initializer writes the machine-readable switches.
No Todoing internals or API behavior are changed.
