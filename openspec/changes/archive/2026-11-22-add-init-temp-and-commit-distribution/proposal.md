# Proposal

## Why

The first trial connection of projects to the Manifest framework is
blocked by three gaps:

1. Subagents do not know about the `temp/` folder: they try to clean
   it up, and the harness blocks deletion commands, interrupting work.
2. Connected projects receive no commit rules: the init distribution
   (`skills/manifest-init/dist/`) is empty.
3. The init script refuses to work on an existing folder — there is no
   defined behavior for connecting to projects that already have files.

## What Changes

- New rule `workflow/temp-folder-rules.ru.md`: what `temp/` is, what
  may be written there, what must never be deleted, the console
  deletion command ban, and the standard boilerplate block for
  subagent prompts (single source of the text).
- New agent file `workflow/agent-rules.ru.md`: minimal first release —
  commit rules section only, plus the preserved-content block marker.
  The agent file does NOT follow `file-structure-rules` (that
  structure is for rule files only); it is modeled on
  `docs/templates/agents.template.md`.
- New accumulator draft `workflow/agent-rules-draft.ru.md`: everything
  known about the agent file content, assembled from
  `docs/templates/` — material for future releases, not shipped.
- Temp boilerplate block wired into subagent definitions
  (`C:/Users/<user>/.zcode/agents/*.md`) — the reliable delivery
  channel: the phrase is already in every subagent prompt.
- New registry `workflow/connected-projects.md`: one entry per
  connected project (name, path, connect date, framework version,
  status).
- Connection scenarios specified for three cases: empty folder /
  non-empty without framework files / non-empty with framework files
  (archive to `.manifest/archive/<timestamp>/`, recreate from
  templates, transfer only the substance of the original rules).
- Distribution build step: framework files sync into
  `skills/manifest-init/dist/` + `VERSION` file.
- Roadmap §1.6 requirement recorded as acceptance: `dist/` must not
  contain `scripts/verify.sh` and `scripts/hooks/`.

## Capabilities

### New Capabilities

- `temp-folder`: the project `temp/` folder — write-anything,
  delete-nothing scratch space with a standard subagent boilerplate.
- `agent-rules-file`: the project agent file `agent-rules` — plain
  structure (no metadata header), commit rules section, preserved-
  content block marker and transfer rule.
- `connected-projects-registry`: Manifest-side registry of connected
  projects, appended by manifest-init on successful connection.
- `init-connection-scenarios`: manifest-init behavior for the three
  folder cases, including archive-based replacement.

### Modified Capabilities

## Impact

- New files: `workflow/temp-folder-rules.ru.md`,
  `workflow/agent-rules.ru.md`, `workflow/agent-rules-draft.ru.md`,
  `workflow/connected-projects.md`.
- Edited: `llms.txt`, user-level subagent definitions
  (`C:/Users/<user>/.zcode/agents/*.md`).
- The companion change in `C:/WorkProjects/skills/manifest-init/`
  fills `dist/` and makes `init.sh` self-contained.
