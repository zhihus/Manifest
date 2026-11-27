# Design: standalone Manifest Init

## Decisions

1. skills/manifest-init/ is the canonical distributable package.
2. Root scripts remain compatibility entry points.
3. Each context file has an independent `context_files.<id>.enabled` switch. All ten switches default to false; install only explicitly enabled files.
4. All writes are additive. Existing destinations are preserved; no automatic archive, overwrite, merge, or migration.
5. New .manifest/manifest.yaml uses format_version 1, enables Todoing, disables OpenSpec, disables all ten context-file switches, and disables all seven optional controls.
6. Existing configuration and checksum are immutable. Verify integrity and schema before any project write.
7. Add OpenSpec scaffolding/config only when missing.
8. Todoing binary installation is user-owned. The installer never downloads it or initializes a store.
9. Add temp/ to .gitignore only when missing.
10. No hooks or optional gates are activated by default.

## Individually selectable context files

| ID | File | Default |
|---|---|---|
| agents | AGENTS.md | disabled |
| llm-navigation | llms.txt | disabled |
| versioning | VERSIONING.md | disabled |
| releases | RELEASES.md | disabled |
| logging | LOG_RULES.md | disabled |
| code-rules | CODE_RULES.md | disabled |
| test-rules | TEST_RULES.md | disabled |
| commit-rules | COMMIT_RULES.md | disabled |
| version | VERSION | disabled |
| llmignore | .llmignore | disabled |

Existing configurations are not migrated automatically. A separate explicit migration process is required before older configurations can adopt per-file settings.

## Verification

Test fresh, partial, repeated, preserved, tampered, and unsupported-legacy cases. Local execution is required before marking the change complete.
