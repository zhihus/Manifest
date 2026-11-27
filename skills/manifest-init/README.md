# Manifest Init

Standalone skill for connecting Manifest to new and existing Git projects. Context files are individually selectable and none are installed by default.

## Layout

- SKILL.md — agent workflow and safety contract.
- scripts/install.sh — additive installer.
- templates/ — standalone copies of approved project templates.
- references/todoing-bootstrap.md — non-destructive Todoing bootstrap contract.
- tests/test-install.sh — regression suite.

## Use

Run `bash scripts/install.sh --project /path/to/project` from the package directory. The target must be a Git work tree. Existing files and configuration are never overwritten.
