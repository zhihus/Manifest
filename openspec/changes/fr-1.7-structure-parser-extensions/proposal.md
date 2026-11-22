# Proposal: extend-structure-parser

## Why

The structure parser currently validates one Markdown file per
invocation. This makes repository-wide checks manual and prevents a
single scheduled run from checking a complete documentation area.

## What Changes

1. Preserve the existing single-file interface.
2. Add recursive directory mode for regular `.md` files.
3. Aggregate results so every discovered file is checked even when
   earlier files contain violations.
4. Document how an external OS scheduler can invoke directory mode.

## Capabilities

### New: structure-parser-directory-validation

The parser can validate every Markdown file below a supplied directory
in one invocation and report the aggregate result.

### New: structure-parser-scheduled-execution

The parser remains a one-shot command. Operating-system schedulers can
invoke it periodically; Manifest does not install or configure a
scheduler.

## Impact

Only Manifest's development script and its usage documentation are
affected. No connected-project distribution or Git hook integration
is included.
