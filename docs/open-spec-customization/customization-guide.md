# Кастомизация OpenSpec — с примерами

*Источники: docs/customize, project-config, customize-schemas (openspec.dev); issue #829*

---

## Механизм 1️⃣: Per-artifact rules (`config.yaml`)

### 📌 Описание
Мы можем управлять тем, **какие дополнительные инструкции модель получает при создании конкретного артефакта** — proposal, specs, design, tasks. Правила добавляются к встроенным и никогда их не заменяют. Управляет файл `openspec/config.yaml`, поле `rules`, ключ — id артефакта.

### 🧩 Пример
**Ситуация:** команда решила, что каждая задача в `tasks.md` обязана содержать проверяемый критерий приёмки, а proposals должны быть короткими — не длиннее 500 слов. Как управлять этим? Вносим в `openspec/config.yaml`:

```yaml
rules:
  tasks:
    - Каждая задача содержит критерий приёмки и ссылку на сценарий из specs
  proposal:
    - Укладывайся в 500 слов
```

### ✅ Результат
При следующем запуске `/opsx:propose` агент получит эти строки прямо в промпте при создании tasks.md и proposal.md — остальные артефакты не затронуты. Мы управляем **требованиями к содержимому конкретных артефактов** без изменения самого workflow. Ограничение: это просит модель, но не проверяет — если правила не работают стабильно, нужен fork схемы.

---

## Механизм 2️⃣: Глобальный контекст (`config.yaml`, поле `context`)

### 📌 Описание
Мы можем управлять тем, **что модель знает о проекте в каждом запуске** — во все артефакты, а также в apply и archive. Поле `context` в том же `openspec/config.yaml`.

### 🧩 Пример
**Ситуация:** продукт кроссплатформенный, и каждая задача/дизайн обязана учитывать Windows, macOS и Linux. Вносим в `openspec/config.yaml`:

```yaml
context: |
  Мы шипим кроссплатформенно. Дизайны и задачи должны покрывать
  Windows, macOS и Linux.
```

### ✅ Результат
Каждый генерируемый артефакт будет учитывать три платформы. Мы управляем **общими фактами и ограничениями проекта**. Нюанс: context попадает во всё — «Write all artifacts in Spanish» здесь сделает все артефакты испаноязычными. Держите правила короткими: всё уходит в контекст модели.

---

## Механизм 3️⃣: Кастомный артефакт (fork схемы) — сценарий «критерии проверки после specs»

### 📌 Описание
Мы можем управлять тем, **какие артефакты вообще существуют**, в каком порядке и с какими зависимостями. Для этого делаем копию встроенной схемы командой `openspec schema fork spec-driven` — она появится в `openspec/schemas/<имя>/`. Затем правим два файла: `schema.yaml` (какие артефакты, что требуют, что получает агент) и `templates/*.md` (скелет документа). После правок обязательна проверка `openspec schema validate <имя>`.

### 🧩 Пример
**Ситуация:** вы хотите, чтобы **после создания specs модель сформировала для себя отдельный документ с критериями проверки**, по которому потом будет сверяться при implement. Вносим в `openspec/schemas/spec-driven-custom/schema.yaml`:

```yaml
artifacts:
- id: verify-criteria
  generates: verify-criteria.md
  description: Критерии проверки реализации по сценариям specs
  template: verify-criteria.md
  requires:
  - specs
  instruction: |
    На основе сценариев из specs выведи список проверяемых критериев:
    каждый критерий должен однозначно маппиться на WHEN/THEN-сценарий
    и быть проверяемым без домыслов.
```

И создаём шаблон `openspec/schemas/spec-driven-custom/templates/verify-criteria.md`:

```markdown
# Verification Criteria

<!-- первый заголовок # обязателен — артефакт его наследует -->

- [ ] (критерий ↔ сценарий из specs)
```

Чтобы tasks зависели от нового артефакта, добавляем `verify-criteria` в список `requires` артефакта `tasks`. Затем:

```bash
openspec schema validate spec-driven-custom
```

и указываем схему в `openspec/config.yaml`:

```yaml
schema: spec-driven-custom
```

### ✅ Результат
Workflow становится: proposal → specs → **verify-criteria** → design → tasks. В каждом изменении появится файл `verify-criteria.md`, который модель заполняет сразу после specs, — мы управляем **самой структурой workflow**, а не только инструкциями. Предостережения: fork — снимок (`openspec update` его никогда не обновляет, апгрейд — пере-fork вручную); команды схем помечены experimental и могут измениться; машинной валидации содержимого нового артефакта нет (см. блок 5).

---

## Механизм 4️⃣: Выбор схемы и хранилища (`config.yaml`)

### 📌 Описание
Мы можем управлять тем, **какую схему и какой корень OpenSpec использует проект**. Поля `schema`, `store`, `references` в `openspec/config.yaml`. Также командой `openspec config profile` выбираем профиль: default (4 команды) или expanded (+ new, continue, ff, verify и др.).

### 🧩 Пример
**Ситуация:** команда хочет облегчённый поток только из proposal и tasks. Вносим в `openspec/config.yaml`:

```yaml
schema: lite   # создана ранее: openspec schema init lite --artifacts proposal,tasks
```

### ✅ Результат
Все новые change-проекты идут по облегчённому пути — мы управляем **тем, какой набор артефактов порождается по умолчанию**. Важно: `init` допускает только 4 встроенных id; нестандартные id — только через ручную правку fork.

---

## Механизм 5️⃣: Именование файлов-задач по утверждённому шаблону

### 📌 Описание
Требования к именованию задач в `tasks.md` (префикс `FR`, нумерация `FR N.M`, kebab-case и т.д.) зафиксированы в файле `openspec-rules.md` в корне проекта — на него ссылается `AGENTS.md` (раздел *Rules → OpenSpec tasks*). Но чтобы **агент OpenSpec** применял эти правила при генерации артефакта `tasks`, они должны попасть в его промпт через per-artifact rules — поле `rules` в `openspec/config.yaml`.

### 🧩 Пример
**Ситуация:** проект требует, чтобы задачи именовались по шаблону `FR N.M-kebab-case-title` (например, `fr-1.1-define-ratio`): префикс FR, сквозная нумерация N.M, без пробелов, без ссылок на файлы в имени. Вносим в `openspec/config.yaml` (в секцию `rules`, которой там ещё нет):

```yaml
rules:
  tasks:
    - Name tasks per openspec-rules.md: prefix FR (Functional Requirement),
      numbering FR N.M where N = wave/group and M = task within group.
    - Task names contain no spaces: replace spaces with hyphens
      (kebab-case). Example: "FR 1.1 Define ratio" -> fr-1.1-define-ratio.
    - A wave is one group (## N.); order groups by dependency so that
      group N depends only on 1..N-1.
    - Never put file references in the task name; file references
      live only in the task body.
```

Дополнительно можно дать агенту прямую ссылку на файл правил через контекст:

```yaml
context: |
  Follow the task naming rules in openspec-rules.md (project root)
  when creating tasks.md.
```

### ✅ Результат
При создании `tasks.md` агент получит правила именования прямо в промпте (порядок инжекции: `<project_context>` → `<rules>` → built-in `<instruction>` → `<template>`) и будет именовать задачи по шаблону `FR N.M-kebab-case-title`. Мы управляем **соглашением об именовании задач**, оставаясь на лёгком уровне кастомизации (без fork схемы). Ограничение то же: правила аддитивны и не гарантированы движком — при нестабильном соблюдении переносим правило в `instruction` артефакта tasks через fork схемы (механизм 3).

---

## 6️⃣ Границы — чем мы управлять НЕ можем

| Ограничение | Почему |
|---|---|
| config.yaml **только добавляет**: не может удалить design, переименовать файл, изменить структуру | это слой инструкций, а не определение workflow — для этого нужен fork схемы |
| `verify` не получает `rules` никогда | verify сверяет реализацию с артефактами «как написано» |
| Валидация `openspec validate` — **hardcoded** (validator.ts, constants.ts); кастомные артефакты вроде `verify-criteria.md` не валидируются машиной | issue **#829** (открыт, design-review): proposal опционального блока `validation` в schema.yaml — пока нестабильно |
| Формат spec-парсера (WHEN/THEN, SHALL) фиксирован | issue **#666** — открытый proposal |
| `openspec update` не трогает `openspec/schemas/` | fork = снимок; обновления built-in в него не приходят |

Смежные proposals: **#777** (schemas ignored for instructions), **#783** (cross-artifact checks).

---

## Итог: кто чем управляет

- 👤 **Пользователь** — существование/порядок артефактов, шаблоны, инструкции, rules/context, профиль. Всё декларативно, в файлах репозитория.
- 🤖 **Модель** — фактическое содержимое артефактов в рамках поданных инструкций; гарантий adherence нет: *«if rules aren't steering behavior consistently, fork a schema»*.
- 🚫 **Никто (пока)** — машинная проверка кастомных артефактов и кастомного spec-формата; schema-команды experimental.
