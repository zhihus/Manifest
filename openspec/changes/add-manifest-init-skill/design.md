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


## Context-file migration design (proposal)

Automatic migration is out of scope for the initial installer. The first release
only supports per-file switches in newly generated configuration and preserves
older configurations without the `context_files` section.

A future migration must be a separate, explicitly approved operation:

1. **Inventory** — enumerate every supported context path, current file state,
   size, and SHA-256. Do not write to the project.
2. **Compare** — compare each existing file with the exact Manifest template
   version. Classify it as absent, byte-identical, or locally modified.
3. **Dry-run report** — show the proposed action per file. Never infer ownership
   from the filename alone.
4. **Per-file decision** — ask the user to keep/adopt the current file, replace
   it with the selected Manifest template, or defer the file. No bulk approval
   may silently replace modified files.
5. **Apply** — only after approval, create a recoverable backup for each file
   selected for replacement, install the chosen template, update that file's
   switch, and refresh the configuration checksum.
6. **Verify** — report before/after hashes and confirm that all unselected files
   are byte-identical.

Because older installations do not record the template baseline from which a
file was derived, a safe three-way merge is not currently possible. Modified
files therefore require manual resolution; no automatic merge is permitted.
Future releases may record a template baseline hash/version when a file is
first installed, enabling a reviewed three-way migration.

The initial installer MUST NOT implement any of these migration writes.
