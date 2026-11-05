# plan-project-structure-head-subprojects — Stage 2


> NOTE 2026-11-05: skills moved out of this repo to the standalone project C:\WorkProjects\skills. Paths below are historical.
> Russian version: plan-project-structure-head-subprojects-stage-2.ru.md
> Status: implemented

## Context
Stage 2: rename the manifest, move templates into `docs/templates/`, update the navigation map. Cross-check against VoiceCaptureEngine (reference) → bring `llm.txt` to the `llms.txt` format.

## Cross-check `llm.txt` ↔ `llms.txt` (VoiceCaptureEngine)
- Name: reference `llms.txt` (with "s") → rename.
- Section: reference `## Rules`, Manifest `## Rules & Manifests` → `## Rules`.
- Heading, Project, Directories, Build — match; `## Sub-projects` — keep (Manifest-specific).

## What will be done

### A1. Rename the manifest
`МАНИФЕСТ_ПРОЕКТА.md` → `project-manifest.md` (EN, kebab-case, `git mv`). Content unchanged (stays in Russian).

### A2. Create `docs/templates/` and move all templates from root (`git mv`)
11 files: `agents.template.md`, `code-rules.template.md`, `commit-rules.template.md`, `log-rules.template.md`, `test-rules.template.md`, `releases.template.md`, `RELEASES.template.compressed.md`, `VERSIONING.template.md`, `version.template`, `llmignore.template`, `llm.template.txt`.
- `llm.template.txt` — rejected variant: moved (per "all templates"), but not included in the navigation map.

### A3. Rename `llm.txt` → `llms.txt` and update content
- `git mv llm.txt llms.txt`.
- Bring section `## Rules & Manifests` → `## Rules`.
- Update links: manifest → `project-manifest.md`; templates → `docs/templates/...`; add `docs/templates/` to Directories.
- Final content:

```markdown
# LLM Navigation Map

## Project

**Manifest** — head (meta) project: defines the architecture of LLM
instruction files and ships reusable skills.
Entry point: `AGENTS.md`

## Directories

* `docs/` — management manifest, context-guard spec.
* `docs/plans/` — plan files (stored compressed; `.en.md` is authoritative).
* `docs/templates/` — file-architecture templates.
* `skills/` — subordinate projects (skills).
* `temp/` — scratch space (gitignored).

## Build

No build step; runs from source.

## Rules

* Workflow: `AGENTS.md`
* Frozen decisions (project manifest): `project-manifest.md`
* Management manifest: `docs/manifest.md` (compressed: `docs/manifest.compact.md`)
* Context guard: `docs/context-files-guard.md`
* File-architecture templates: `docs/templates/agents.template.md`,
  `docs/templates/code-rules.template.md`, `docs/templates/commit-rules.template.md`,
  `docs/templates/log-rules.template.md`, `docs/templates/test-rules.template.md`,
  `docs/templates/releases.template.md`, `docs/templates/VERSIONING.template.md`,
  `docs/templates/version.template`, `docs/templates/llmignore.template`

## Sub-projects (skills)

* `skills/compress-context/` — context-compression skill.
  Agent file: `skills/compress-context/AGENTS.md`.
* `skills/compress-context-benchmark/` — benchmark for the compression skill.
  Agent file: `skills/compress-context-benchmark/AGENTS.md`.
```

### A4. Update the link in `AGENTS.md`
`llm.txt` → `llms.txt` (in the **Project structure** section: `Navigation map: llm.txt` → `Navigation map: llms.txt`).

## Files
- `project-manifest.md` — renamed (from `МАНИФЕСТ_ПРОЕКТА.md`)
- `docs/templates/` — new folder; 11 templates moved from root
- `llms.txt` — renamed (from `llm.txt`) + updated (manifest, templates, `## Rules` section)
- `AGENTS.md` — link `llm.txt` → `llms.txt`

## Verification
- `project-manifest.md` exists; `МАНИФЕСТ_ПРОЕКТА.md` is absent from root.
- `docs/templates/` exists; all 11 templates are in it; no `*.template.*` or `llm.template.txt` in root.
- `llms.txt` exists; `llm.txt` is absent from root; section is `## Rules` (not `## Rules & Manifests`).
- All links in `llms.txt` resolve: `project-manifest.md`, `docs/templates/...`, `skills/.../AGENTS.md`.
- `AGENTS.md` links to `llms.txt` (not `llm.txt`).