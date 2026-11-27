# Design: standalone Manifest Init

## Decisions

1. skills/manifest-init/ is the canonical distributable package.
2. Root scripts remain compatibility entry points.
3. Install ten mandatory context files from the approved templates.
4. All writes are additive. Existing destinations are preserved; no automatic archive, overwrite, merge, or migration.
5. New .manifest/manifest.yaml uses format_version 1, enables Todoing and OpenSpec independently, and disables all seven optional controls.
6. Existing configuration and checksum are immutable. Verify integrity and schema before any project write.
7. Add OpenSpec scaffolding/config only when missing.
8. Todoing binary installation is user-owned. The installer never downloads it or initializes a store.
9. Add temp/ to .gitignore only when missing.
10. No hooks or optional gates are activated by default.

## Mandatory context

AGENTS.md, llms.txt, VERSIONING.md, RELEASES.md, LOG_RULES.md, CODE_RULES.md, TEST_RULES.md, COMMIT_RULES.md, VERSION, .llmignore.

## Verification

Test fresh, partial, repeated, preserved, tampered, and unsupported-legacy cases. Local execution is required before marking the change complete.
