# plan-project-structure-head-subprojects — Stage 1


> NOTE 2026-11-05: skills moved out of this repo to the standalone project C:\WorkProjects\skills. Paths below are historical.
> Russian version: plan-project-structure-head-subprojects-stage-1.ru.md
> Status: implemented

## Context
`C:\WorkProjects\Manifest` — head (meta) project; defines the architecture of LLM instruction files. Sub-projects (skills) live in `skills/`. Task: reflect the head/subordinate structure in the root agent file, create the `llm.txt` navigation map with links to all related files, rename some templates to kebab-case, and set plan-reading rules.

## What will be done
1. Create the `docs/plans/` folder.
2. Create two plan files in `docs/plans/`, compressed (compress-context skill: `skills/compress-context/SKILL.md` + `compress-context-rules.template.md`):
   - `PLAN-1.0.0-project-structure-head-subprojects.ru.md` — RU (compressed).
   - `PLAN-1.0.0-project-structure-head-subprojects.en.md` — EN (compressed).
3. Create `llm.txt` (kebab-case) — navigation map with links to all related files. `llm.template.txt` in root is a rejected old variant, unused.
4. Rename 4 templates to kebab-case (no root files with these names exist, so their templates are renamed):
   - `CODE_RULES.template.md` → `code-rules.template.md`
   - `COMMIT_RULES.template.md` → `commit-rules.template.md`
   - `LOG_RULES.template.md` → `log-rules.template.md`
   - `TEST_RULES.template.md` → `test-rules.template.md`
5. Modify root `AGENTS.md` — add **Project structure** and **Plans** sections + a link to `llm.txt`.
6. Create `skills/compress-context-benchmark/AGENTS.md` (new).

## Changes

### 1. Root AGENTS.md — sections (EN) after the Language and temp/ rules:
```markdown
**Project structure.** This is the head project. It contains subordinate
projects (skills) under `skills/`. Navigation map: `llm.txt`.

- When the user asks to work with a sub-project from this (head) folder,
  read that sub-project's `AGENTS.md` before working on it.
- Every new sub-project must be registered here with a link to its
  `AGENTS.md`.

Sub-projects:

- `skills/compress-context/` — context-compression skill.
  Agent file: `skills/compress-context/AGENTS.md`.
- `skills/compress-context-benchmark/` — benchmark for the compression skill.
  Agent file: `skills/compress-context-benchmark/AGENTS.md`.

**Plans.** Plan files live in `docs/plans/`. Plan files are stored compressed;
compression is done with the compress-context skill. Always read the English
version (`.en.md`) of a plan. If no English version exists, read the version
in any language. English takes priority.
```

Key rules:
- `llm.txt` is the navigation map; linked in `AGENTS.md`.
- Read a sub-project's `AGENTS.md` only when the user asks to work with it from the head project's folder.
- Every new sub-project is registered here with a link to its `AGENTS.md`.
- Plans live in `docs/plans/`, stored compressed (compress-context); read the English version; if no English version, any version; English takes priority.

### 2. llm.txt (new, root, kebab-case) — navigation map:
```markdown
# LLM Navigation Map

## Project

**Manifest** — head (meta) project: defines the architecture of LLM
instruction files and ships reusable skills.
Entry point: `AGENTS.md`

## Directories

* `docs/` — management manifest, context-guard spec.
* `docs/plans/` — plan files (stored compressed; `.en.md` is authoritative).
* `skills/` — subordinate projects (skills).
* `temp/` — scratch space (gitignored).

## Build

No build step; runs from source.

## Rules & Manifests

* Workflow: `AGENTS.md`
* Frozen decisions (project manifest): `МАНИФЕСТ_ПРОЕКТА.md`
* Management manifest: `docs/manifest.md` (compressed: `docs/manifest.compact.md`)
* Context guard: `docs/context-files-guard.md`
* File-architecture templates: `agents.template.md`, `code-rules.template.md`,
  `commit-rules.template.md`, `log-rules.template.md`, `test-rules.template.md`,
  `releases.template.md`, `VERSIONING.template.md`, `version.template`,
  `llmignore.template`

## Sub-projects (skills)

* `skills/compress-context/` — context-compression skill.
  Agent file: `skills/compress-context/AGENTS.md`.
* `skills/compress-context-benchmark/` — benchmark for the compression skill.
  Agent file: `skills/compress-context-benchmark/AGENTS.md`.
```

### 3. Template renames (kebab-case):
| Was | Now |
|---|---|
| `CODE_RULES.template.md` | `code-rules.template.md` |
| `COMMIT_RULES.template.md` | `commit-rules.template.md` |
| `LOG_RULES.template.md` | `log-rules.template.md` |
| `TEST_RULES.template.md` | `test-rules.template.md` |

> Uppercase target-name references (`CODE_RULES.md` etc.) in `МАНИФЕСТ_ПРОЕКТА.md`, `agents.template.md`, `llm.template.txt` point to target files (not yet created) and are not renamed here. If needed, add as a separate step.

### 4. skills/compress-context-benchmark/AGENTS.md (new) — mirrors compress-context/AGENTS.md, references only the benchmark's real files:
```markdown
# Agents

- `SKILL.md` — benchmark protocol (test suite, metrics, release gates).
- `benchmark-results.md` — recorded benchmark results per release.
```

## Files
- `docs/plans/` — new folder
- `docs/plans/PLAN-1.0.0-project-structure-head-subprojects.ru.md` — new (compressed)
- `docs/plans/PLAN-1.0.0-project-structure-head-subprojects.en.md` — new (compressed)
- `llm.txt` — new (kebab-case)
- `code-rules.template.md`, `commit-rules.template.md`, `log-rules.template.md`, `test-rules.template.md` — renamed
- `AGENTS.md` — add Project structure, Plans, link to llm.txt
- `skills/compress-context-benchmark/AGENTS.md` — new

## Verification
- `docs/plans/` exists; both plan files are in it; `.ru.md` is RU, `.en.md` is EN (translation of one plan); both compressed with the compress-context skill.
- `llm.txt` is in root (kebab-case); links to all related files; `AGENTS.md` links to `llm.txt`.
- 4 templates renamed to kebab-case; old uppercase names no longer exist in root.
- Links in `AGENTS.md` and `llm.txt` resolve: `skills/compress-context/AGENTS.md` exists; `skills/compress-context-benchmark/AGENTS.md` now exists.
- Project structure has the rule for registering new sub-projects.
- Plans fixes: compression via compress-context, English priority, "if no English version — any version".
- Benchmark `AGENTS.md` references only files that exist in its directory (`SKILL.md`, `benchmark-results.md`).
- Root `AGENTS.md` stays in English; Language and temp/ rules preserved.