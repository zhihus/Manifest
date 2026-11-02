# plan-project-structure-head-subprojects — этап 2

> English version: plan-project-structure-head-subprojects-stage-2.en.md
> Статус: выполнен

## Контекст
Этап 2: переименование манифеста, перенос шаблонов в `docs/templates/`, обновление навигационной карты. Сверка с VoiceCaptureEngine (референс) → привести `llm.txt` к формату `llms.txt`.

## Сверка `llm.txt` ↔ `llms.txt` (VoiceCaptureEngine)
- Имя: референс `llms.txt` (с «s») → переименовать.
- Секция: референс `## Rules`, Manifest `## Rules & Manifests` → `## Rules`.
- Heading, Project, Directories, Build — совпадают; `## Sub-projects` — оставить (специфика Manifest).

## Что будет сделано

### A1. Переименовать манифест
`МАНИФЕСТ_ПРОЕКТА.md` → `project-manifest.md` (EN, kebab-case, `git mv`). Содержимое не меняется (остаётся на русском).

### A2. Создать `docs/templates/` и перенести все шаблоны из корня (`git mv`)
11 файлов: `agents.template.md`, `code-rules.template.md`, `commit-rules.template.md`, `log-rules.template.md`, `test-rules.template.md`, `releases.template.md`, `RELEASES.template.compressed.md`, `VERSIONING.template.md`, `version.template`, `llmignore.template`, `llm.template.txt`.
- `llm.template.txt` — отвергнутая вариация: переносится (по «все шаблоны»), но в навигационную карту не включается.

### A3. Переименовать `llm.txt` → `llms.txt` и обновить содержимое
- `git mv llm.txt llms.txt`.
- Привести секцию `## Rules & Manifests` → `## Rules`.
- Обновить ссылки: манифест → `project-manifest.md`; шаблоны → `docs/templates/...`; добавить `docs/templates/` в Directories.
- Итоговое содержимое:

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

### A4. Обновить ссылку в `AGENTS.md`
`llm.txt` → `llms.txt` (в секции **Project structure**: `Navigation map: llm.txt` → `Navigation map: llms.txt`).

## Файлы
- `project-manifest.md` — переименован (из `МАНИФЕСТ_ПРОЕКТА.md`)
- `docs/templates/` — новая папка; 11 шаблонов перенесены из корня
- `llms.txt` — переименован (из `llm.txt`) + обновлён (манифест, шаблоны, секция `## Rules`)
- `AGENTS.md` — ссылка `llm.txt` → `llms.txt`

## Проверка
- `project-manifest.md` существует; `МАНИФЕСТ_ПРОЕКТА.md` в корне отсутствует.
- `docs/templates/` существует; все 11 шаблонов в ней; в корне `*.template.*` и `llm.template.txt` нет.
- `llms.txt` существует; `llm.txt` в корне отсутствует; секция `## Rules` (не `## Rules & Manifests`).
- Все ссылки в `llms.txt` резолвятся: `project-manifest.md`, `docs/templates/...`, `skills/.../AGENTS.md`.
- `AGENTS.md` ссылается на `llms.txt` (не `llm.txt`).