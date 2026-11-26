# Design: distribute tz-rezultat-hz as an independent skill

## Decision

Keep the skill in `skills/tz-rezultat-hz/` as a self-contained, independently maintained component. Manifest does not import its Python code, bootstrap implementation, or 1C-specific workflow into the Manifest core.

## Windows-first integration

The first supported Manifest-managed installation target is Windows x64. The skill's own upstream source currently contains both Windows and Linux launchers; preserve the complete upstream package rather than deleting platform files. This integration does not claim Linux installation through Manifest is implemented.

## Installation boundary

Project connection must not run the skill bootstrap. The agent/user selects the skill, installs its directory into the selected harness, reviews the component list by running `bootstrap.ps1`, and explicitly confirms before running `bootstrap.ps1 -Full`. This prevents an unexpected network download or runtime installation during generic project initialization.

## Distribution integrity

Copy the entire upstream skill folder, preserve relative paths and executable modes, and include upstream `LICENSE` and `THIRD-PARTY.md`. Keep `tests/test_bootstrap.py` under Manifest's `tests/` tree, outside the distributable package. The upstream repository remains the source of truth for skill implementation.
