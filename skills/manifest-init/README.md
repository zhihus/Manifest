# Manifest Init

Standalone skill for connecting Manifest to Git projects and managing standalone Todoing tasks after connection. Context files are individually selectable and none are installed by default.

## Layout

- SKILL.md — agent workflow and safety contract.
- scripts/install.sh — additive installer.
- templates/ — standalone copies of approved project templates.
- references/todoing-bootstrap.md — non-destructive Todoing bootstrap contract.
- references/todoing-agent-workflow.md — runtime task management after connection (Todoing-only mode).
- tests/test-install.sh — regression suite.

## Use

Run `bash scripts/install.sh --project /path/to/project` from the package directory. The target must be a Git work tree. Todoing is enabled and OpenSpec is disabled by default. Context files are individually selectable, for example `--context-file agents=enabled`; all are disabled by default. Existing files and configuration are never overwritten.
