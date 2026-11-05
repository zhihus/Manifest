# plan-project-structure-head-subprojects — этап 1


> NOTE 2026-11-05: skills moved out of this repo to the standalone project C:\WorkProjects\skills. Paths below are historical.
> English version: plan-project-structure-head-subprojects-stage-1.en.md
> Статус: выполнен

## Контекст
`C:\WorkProjects\Manifest` — головной (мета) проект; задаёт архитектуру файлов инструкций для LLM. Под-проекты (скиллы) — в `skills/`. Задача: отразить структуру «головной/подчинённые» в корневом файле агента, создать навигационную карту `llm.txt` со ссылками на все связанные файлы, переименовать часть шаблонов в kebab-case, задать правила чтения планов.

## Что будет сделано
1. Создать папку `docs/plans/`.
2. Создать два файла плана в `docs/plans/` — сжатыми (скилл compress-context: `skills/compress-context/SKILL.md` + `compress-context-rules.template.md`):
   - `PLAN-1.0.0-project-structure-head-subprojects.ru.md` — RU (сжатый).
   - `PLAN-1.0.0-project-structure-head-subprojects.en.md` — EN (сжатый).
3. Создать `llm.txt` (kebab-case) — навигационная карта со ссылками на все связанные файлы. `llm.template.txt` в корне — отвергнутая старая вариация, не используется.
4. Переименовать 4 шаблона в kebab-case (в корне нет файлов с такими именами → переименовываются их шаблоны):
   - `CODE_RULES.template.md` → `code-rules.template.md`
   - `COMMIT_RULES.template.md` → `commit-rules.template.md`
   - `LOG_RULES.template.md` → `log-rules.template.md`
   - `TEST_RULES.template.md` → `test-rules.template.md`
5. Изменить корневой `AGENTS.md` — добавить секции **Project structure**, **Plans** + ссылку на `llm.txt`.
6. Создать `skills/compress-context-benchmark/AGENTS.md` (новый).

## Изменения

### 1. Корневой AGENTS.md — секции (EN) после правил Language и temp/:
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

Ключевые правила:
- `llm.txt` — навигационная карта; ссылка в `AGENTS.md`.
- Читать `AGENTS.md` под-проекта — только когда пользователь просит поработать с ним из папки головного проекта.
- Каждый новый под-проект регистрируется ссылкой на его `AGENTS.md`.
- Планы в `docs/plans/`, хранятся сжатыми (compress-context); читать английскую версию; если англ. нет — любую; приоритет — английский.

### 2. llm.txt (новый, корень, kebab-case) — навигационная карта:
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

### 3. Переименование шаблонов (kebab-case):
| Было | Стало |
|---|---|
| `CODE_RULES.template.md` | `code-rules.template.md` |
| `COMMIT_RULES.template.md` | `commit-rules.template.md` |
| `LOG_RULES.template.md` | `log-rules.template.md` |
| `TEST_RULES.template.md` | `test-rules.template.md` |

> Ссылки на верхнерегистровые целевые имена (`CODE_RULES.md` и т.д.) в `МАНИФЕСТ_ПРОЕКТА.md`, `agents.template.md`, `llm.template.txt` — на целевые файлы (ещё не созданы), не переименовываются. Если нужно — отдельным шагом.

### 4. skills/compress-context-benchmark/AGENTS.md (новый) — по образцу compress-context/AGENTS.md, ссылки на реально существующие файлы бенчмарка:
```markdown
# Agents

- `SKILL.md` — benchmark protocol (test suite, metrics, release gates).
- `benchmark-results.md` — recorded benchmark results per release.
```

## Файлы
- `docs/plans/` — новая папка
- `docs/plans/PLAN-1.0.0-project-structure-head-subprojects.ru.md` — новый (сжатый)
- `docs/plans/PLAN-1.0.0-project-structure-head-subprojects.en.md` — новый (сжатый)
- `llm.txt` — новый (kebab-case)
- `code-rules.template.md`, `commit-rules.template.md`, `log-rules.template.md`, `test-rules.template.md` — переименованы
- `AGENTS.md` — добавить Project structure, Plans, ссылку на llm.txt
- `skills/compress-context-benchmark/AGENTS.md` — новый

## Проверка
- `docs/plans/` существует; оба файла плана в ней; `.ru.md` — RU, `.en.md` — EN (перевод одного плана); оба сжаты скиллом compress-context.
- `llm.txt` в корне (kebab-case); ссылки на все связанные файлы; `AGENTS.md` ссылается на `llm.txt`.
- 4 шаблона переименованы в kebab-case; старые верхнерегистровые имена в корне отсутствуют.
- Ссылки в `AGENTS.md` и `llm.txt` резолвятся: `skills/compress-context/AGENTS.md` существует; `skills/compress-context-benchmark/AGENTS.md` теперь существует.
- В Project structure — правило регистрации новых под-проектов.
- В Plans — сжатие через compress-context, приоритет английского, «если англ. нет — любая версия».
- `AGENTS.md` бенчмарка ссылается только на существующие в его каталоге файлы (`SKILL.md`, `benchmark-results.md`).
- Корневой `AGENTS.md` на английском; правила Language и temp/ сохранены.