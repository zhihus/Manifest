# Proposal

## Why

Manifest управляет OpenSpec-пайплайном (Аналитик → Архитектор →
Планировщик → Тестировщик → Реализатор → Ревьюэр → Архив), но не хранит
состояние задач: нет источника истины для статусов, блокировок, истории
версий и итоговых commit-ссылок. Целевой контракт интеграции
(`docs/architecture/todoing-contract.ru.md`) определён, а универсальные
расширения Todoing API v1 (external references, Review history,
revision_count, final commit marker) реализованы в Todoing и подтверждены
аудитом. Интеграция становится возможной: Manifest потребляет публичный
JSON API v1 через CLI `todoing api --json`, а Main Orchestrator становится
единственным клиентом Todoing API.

Без этого изменения статусы задач, их блокировки и история не имеют
единого источника, а согласованность Todoing ↔ OpenSpec ↔ Git
не проверяема.

## What Changes

- Main Orchestrator (основная сессия агента) становится единственным
  клиентом Todoing API; ролевые субагенты не получают lock token и не
  вызывают Todoing.
- Вводится механизм Project Identity: стабильный Project ID хранится в
  `.manifest/project-id` и передаётся в каждом запросе API.
- Определяется модель блокировок (lock custody), учитывающая блокирующее
  выполнение ролевого субагента: Orchestrator не может поддерживать
  heartbeat во время работы субагента, поэтому lease настраивается на
  покрытие hard timeout выполнения агента.
- Определяется процедура bootstrap хранилища: установка Todoing
  выполняется пользователем, `store.init` не перезаписывает существующее
  хранилище и legacy Markdown-данные.
- Определяется отображение жизненного цикла: один Todoing task
  соответствует одному OpenSpec change; статусы, Review, завершение и
  отмена привязаны к операциям Todoing API.
- Определяется восстановление после частичного сбоя между Todoing,
  OpenSpec и Git: системы не образуют транзакции, повтор операций
  идемпотентен или явный.

## Capabilities

- `todoing-project-identity` — генерация, валидация и защита Project ID.
- `todoing-store-bootstrap` — инициализация хранилища, конфигурация,
  отказ от перезаписи legacy и существующего store.
- `todoing-task-state` — отображение OpenSpec change на Todoing task,
  статусы, external reference, зависимости.
- `todoing-lock-custody` — приобретение, heartbeat, освобождение и
  recovery блокировок с учётом блокирующего выполнения субагента.
- `todoing-review-cycle` — цикл Review: передача на проверку, запись
  Review, revision_count, возврат и одобрение.
- `todoing-completion-recovery` — итоговое завершение, отмена и
  восстановление после частичного сбоя между системами.

## Out of scope

- Реализация интеграции (выполняется отдельным решением после одобрения
  данного change).
- Изменения Todoing: Manifest не изменяет Todoing и не переносит в него
  Manifest-specific логику.
- Daemon, API wrapper, hooks/events как гарантия корректности.
- Автоматическая миграция legacy данных (отдельная non-destructive
  процедура).
- GUI Todoing и общий обзор задач между проектами.