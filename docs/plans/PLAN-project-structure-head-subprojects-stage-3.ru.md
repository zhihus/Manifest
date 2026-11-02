# PLAN-project-structure-head-subprojects — этап 3

> English version: PLAN-project-structure-head-subprojects-stage-3.en.md
> Статус: не выполнен

## Контекст
Головной проект `Manifest` и под-проекты (скиллы) — документационные (без кода). Шаблоны — 2 категории: для **кодовых** проектов (типа VoiceCaptureEngine) и для **документационных**; часть файлов общая (сейчас `AGENTS.template.md` не различается). Этап 3: шаблоны для документационных проектов, обновление RELEASES, SETTINGS, OpenSpec-правил.

## Что будет сделано

### B1. `content-rules.template.md`
Шаблон правил для **документационных** проектов (проекты, которые не пишут код, а создают документацию). Содержимое:
- Правила для документационных проектов (аналог `code-rules.template.md`, но для документации): Clarity, Accuracy, Completeness, Consistency, Structure, Change Discipline, Verification.
- **Блок «Защита контекст-файлов»** (TEMPORARY): при изменении файлов агента/правил — показать изменения + ревью + явное согласие пользователя перед коммитом (пока нет Git Hook).
- **Git-воркфлоу: НЕ РЕШЕНО** (см. «Нерешённые вопросы»).

### B2. `SETTINGS.template.md`
Шаблон правил настроек (по образцу `SETTINGS.md` из VoiceCaptureEngine, но как шаблон с плейсхолдерами).

### B3. `RELEASES.template.md` (обновить)
- Ветки: `dev`/`master` → `develop`/`master`.
- `develop` — вся разработка (включая документационные проекты).
- `master` — утверждённые документы / release-ready.
- Для кодовых проектов — аналогичная схема.
- Ветка для OpenSpec-изменений: имя ветки связано с именованием задач OpenSpec (см. `open-spec-rules.template.md`).

### B4. `open-spec-rules.template.md`
Общие правила именования OpenSpec-задач (из `compress-context/open-spec-rules.md`): FR prefix, N.M numbering, kebab-case, wave. Это **общие** правила (не скилл-специфичные).

### B5. Взаимная ссылка
Взаимная ссылка между RU и EN файлами каждого этапа (RU→EN, EN→RU).

### B6. Правило для головного проекта (Manifest)
Шаблоны в `docs/templates/` — исходный материал, не реальные документы; на них ничего не ссылается. Специфично для Manifest; попадает в живой `AGENTS.md`.

## Нерешённые вопросы
1. **Git-воркфлоу для документационных проектов** (ветка на задачу, merge into develop, stop-and-report): куда добавить — не решено. Возможно, отдельный файл агента.
2. **Отдельный файл контекста проекта** для документационных проектов: возможно, добавить файл агента. Не решено.

## Файлы
- `docs/templates/content-rules.template.md` — новый (документационные проекты + защита контекста)
- `docs/templates/SETTINGS.template.md` — новый (правила настроек)
- `docs/templates/open-spec-rules.template.md` — новый (именование OpenSpec-задач)
- `docs/templates/RELEASES.template.md` — обновлён (develop/master, OpenSpec-ветки)
- `AGENTS.md` — обновлён (правило о шаблонах: исходный материал, не реальные документы; на них ничего не ссылается)

## Проверка
- `content-rules.template.md` — правила для документационных проектов + блок защиты контекста.
- `SETTINGS.template.md` — плейсхолдеры для настроек.
- `open-spec-rules.template.md` — FR, N.M, kebab-case, wave.
- `RELEASES.template.md` — ветки `develop`/`master`; упоминание OpenSpec-веток.
- `AGENTS.md` содержит правило о шаблонах; `docs/templates/` не появляется в `llms.txt` / `AGENTS.md`.
- Все ссылки в `llms.txt` и `AGENTS.md` резолвятся на реально существующие файлы.