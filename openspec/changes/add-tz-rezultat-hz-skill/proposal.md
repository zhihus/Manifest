# Add tz-rezultat-hz skill distribution

## Scope

Add the existing standalone `tz-rezultat-hz` skill to the Manifest distribution without absorbing it into the Manifest core. The first Manifest-managed installation target is Windows x64.

## Requirements

- Preserve the complete upstream skill directory and its internal relative paths.
- Preserve the upstream MIT license and third-party notices.
- Keep bootstrap tests outside the distributable skill directory.
- Do not execute the bootstrap automatically during project connection.
- On Windows, installation instructions must use `bootstrap.ps1`; first invocation is inspection-only, and `-Full` requires explicit user confirmation.
- Do not claim that Manifest-managed Linux installation is supported until separately implemented and tested.
- Do not add customer-specific files, local configuration, temporary artifacts, or unrelated repository content.

## Source

`https://github.com/zhihus/tz-rezultat-hz`, branch `main`.
