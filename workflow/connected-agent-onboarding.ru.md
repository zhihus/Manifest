# Инструкция агенту подключённого проекта

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.1.0**  
> **Updated: 2026-11-28**

# Description
Временный обязательный контекст до появления автоматической генерации Manifest-файлов по ролям и процессам.

## 1. При старте

Main Orchestrator обязан:
1. Прочитать AGENTS.md и проверить доступ к файлам по .llmignore.
2. Проверить .manifest/manifest.yaml, checksum, format_version и switches по схеме установленной версии Manifest.
3. Определить режим OpenSpec/Todoing по switches.
4. При включённом Todoing проверить бинарник, Project ID, config и store по §6.1 workflow/README.en.md.

При ошибке checksum, неизвестной схеме, несовпадении Project ID или повреждении store — остановиться. Не исправлять конфигурацию и не переинициализировать хранилище автоматически.

Todoing вызывается через `todoing --json api`; бинарник определяется через `TODOING_BIN` или PATH. Runtime не должен зависеть от dev-скриптов/кэша Manifest. Требуемый baseline — commit `653788a954d2a120db1beba854308982814d8222` или проверенный потомок; номер версии не доказывает provenance.

## 2. Режимы

- **Todoing + OpenSpec:** coordinated mode; одна Todoing task на одну OpenSpec change.
- Для нового подключения OpenSpec включается по умолчанию. Существующий `enabled: false` не считать осознанным отказом пользователя: при onboarding включить switch по схеме и пересчитать checksum. Не отключать OpenSpec без явного решения пользователя.
- **Только Todoing:** задачи без OpenSpec и без фиктивных `openspec.change`.
- **Только OpenSpec:** спецификации без Todoing API/store.
- **Оба выключены:** не вызывать компоненты.

Если нужный компонент выключен, сообщить пользователю. Не обходить switch и не менять конфигурацию без разрешения.

## 3. Когда создавать артефакты

Консультация, исследование, обсуждение идеи и разовая правка текста сами по себе не требуют change/task.

Изменение поведения продукта, архитектуры, публичного контракта или существенного процесса обычно требует OpenSpec change. До реализации подготовить proposal/spec, при необходимости design и tasks.md. Создание артефактов не означает разрешение на реализацию.

В coordinated mode Orchestrator сначала ищет существующую связанную задачу и переиспользует её; дубликаты запрещены.

## 4. Связь OpenSpec ↔ Todoing

Только в coordinated mode:
- одна OpenSpec change = ровно одна Todoing task;
- task title = точный ID change;
- external reference: namespace `openspec.change`, value = ID, relation = `implements`, scope = `project`;
- перед созданием проверить `task.list` и `task.external-ref.list`; при неоднозначности остановиться;
- FR, декомпозиция и исполнительские шаги остаются в `tasks.md`, отдельные задачи Todoing для них не создаются.

Источники истины: OpenSpec — требования; Todoing — task status/outcome, версии, история, locks и Review; Git — фактические изменения и SHA; Manifest координирует согласованность.

## 5. Полномочия и lifecycle

Main Orchestrator — единственный клиент Todoing API. Ролевые агенты работают с порученными артефактами, но не создают/изменяют tasks, статусы и locks и не получают lock token.

`backlog → ready → in_progress → review → verified → completed`

- `backlog → ready` — только по явному решению пользователя; перед lock/dispatch Orchestrator утверждает baseline через `task.version.approve`.
- Orchestrator управляет переходами и назначением исполнителя; Review выполняет независимый Reviewer.
- `changes_requested` возвращает задачу в `in_progress`; после исправлений нужен новый Review.
- `verified → completed` — после финальных проверок и обязательных операций OpenSpec/Git.
- Отмена — только по решению пользователя. Архивирование не заменяет workflow status.
- Одна активная задача: Orchestrator не начинает выполнение другой задачи, пока текущая активна (`in_progress`, `review` или `verified`). Активной не считается задача в `backlog`/`ready` и задача с результатом `completed`/`cancelled`. «Начать выполнение» — получить lock и перевести задачу в `in_progress` (или далее); создание задачи в `backlog` и перевод в `ready` не являются началом выполнения и разрешены. Единственное исключение — явная инструкция пользователя. Правило не зависит от инициатора и способа (пользователь, агент, subagent, CLI, JSON API); `actor_id` — атрибуция, а не освобождение. При блокировке — сообщить активную задачу и дождаться решения пользователя.

Подробные API-последовательности, lock/heartbeat/fencing/recovery, Review records, final commit и partial-failure recovery: §§6.2–6.6 `workflow/README.en.md` и `docs/architecture/todoing-contract.ru.md`. При потере ответа сначала сверить состояние; не повторять неидемпотентную операцию вслепую.

Полномочия — процедурные: Todoing не удостоверяет личность или согласие пользователя; `actor_id` не является доказательством.

## 6. Рабочий цикл

Orchestrator восстанавливает состояние → уточняет требования → Analyst готовит proposal/spec → Architect при необходимости design → Planner tasks.md → Orchestrator проверяет артефакты и создаёт/переиспользует task в backlog → пользователь разрешает ready → Orchestrator утверждает baseline и запускает роли последовательно → независимый Review → исправления при необходимости → финальные проверки и согласование OpenSpec/Todoing/Git → отчёт со ссылками, Review, проверками и итоговым SHA.

Параллельные исполнители в одном проекте запрещены текущим workflow. Для документационных изменений использовать doc-only путь OpenSpec.

## 7. Восстановление и замена инструкции

После перезапуска сверить Todoing (task, versions, history, reviews, references, lock), OpenSpec (change/spec/archive) и Git (branch, worktree, commit/merge SHA). При неоднозначности остановиться и передать решение пользователю; не создавать дубликаты и не повторять операции вслепую.

Инструкция обязательна, пока Manifest не генерирует и автоматически подключает контекст по ролям/процессам. Снять её обязательность можно только после переноса правил, сохранения точек входа, проверки всех switch-режимов и сквозного теста обнаружения контекста.
