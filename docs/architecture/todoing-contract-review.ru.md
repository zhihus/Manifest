> **Исторический документ.** Этот обзор отражает ранний анализ Todoing и не является актуальным нормативным контрактом. Для текущей интеграции использовать только [контракт Todoing для Manifest](todoing-contract.ru.md).

# Матрица соответствия: целевой контракт Todoing ↔ todoing-x

**Версия:** 2.0.0-draft  
**Статус:** рабочая редакция  
**Назначение:** зафиксировать соответствие целевого контракта todoing-contract.ru.md
текущей реализации Todoing и определить блокирующие расширения перед интеграцией
Manifest.

**Базовая версия Todoing:** zhihus/todoing-x main @
947048d3864e99c7d0dfcc48889a084e0a99e42d.

**Метод:** использован опубликованный отчёт исходного аудита
todoing-implementation-audit.ru.md и выполнена повторная документальная
сверка с API operations/schema, consumer contract и OpenSpec specifications.
Это не повторный полный аудит исходников и не независимое внешнее ревью кода.

## 1. Сводная матрица

| # | Требование | Текущая реализация | Целевой статус |
|---|---|---|---|
| 1 | Версионируемый JSON API v1, envelope, error codes | Реализовано | Поддерживается |
| 2 | Project ID и project-local store | Реализовано | Поддерживается; Manifest хранит стабильный ID |
| 3 | Создание, чтение, изменение, статусы и outcomes | Реализовано | Поддерживается |
| 4 | Конфигурируемые статусы и переходы | Реализовано через .todoing/config.toml | Поддерживается |
| 5 | Immutable task versions и append-only operation history | Реализовано | Поддерживается |
| 6 | Approval baseline | Реализовано | Поддерживается |
| 7 | Exclusive locks, heartbeat, recovery, fencing | Реализовано | Поддерживается |
| 8 | Dependencies и cycle prevention | Реализовано | Поддерживается |
| 9 | Archive/restore без физического удаления | Реализовано | Поддерживается |
| 10 | Git commit references (full SHA) | Реализовано | Поддерживается для обычных refs |
| 11 | Отдельный final commit marker | Отсутствует | Требуется универсальное расширение Todoing |
| 12 | Generic external references | Отсутствует | Требуется универсальное расширение Todoing |
| 13 | Structured Review history | Отсутствует | Требуется универсальное расширение Todoing |
| 14 | revision_count с атомарным increment | Отсутствует | Требуется универсальное расширение Todoing |
| 15 | Generic lifecycle events/hooks | Не предоставляется SQLite backend | Отложено; Manifest не зависит |
| 16 | Runtime capabilities discovery | Отсутствует | Не блокирует MVP |
| 17 | Verify, migrate, verified snapshot | Реализовано | Поддерживается |

## 2. Подтверждённые границы интеграции

### 2.1. Todoing

Todoing отвечает за:

- project-local SQLite task store;
- task state, configurable status/outcome, dependencies;
- immutable versions, append-only operation history, approval baseline;
- exclusive locks, leases, recovery и fencing;
- archive/restore;
- обычные Git commit references;
- JSON API v1, migration, verify и snapshot.

Todoing не аутентифицирует actor_id, не определяет consumer roles и не управляет
OpenSpec/Git workflow.

### 2.2. Manifest

Manifest отвечает за:

- стабильный Project ID и его передачу в каждом API request;
- выбор конфигурации статусов и её безопасную установку до store.init;
- user approval, actor trust, роли и оркестрацию;
- OpenSpec workflow и трактовку generic external references;
- Git branch/review/merge policy;
- проверку согласованности Todoing ↔ OpenSpec ↔ Git;
- snapshot destination, retention и backup policy.

Manifest не читает SQLite напрямую и не дублирует workflow status/outcome.

## 3. Обязательные расширения Todoing

Следующие требования ранее утверждены архитектурой Manifest и должны быть
реализованы в Todoing универсально, без Manifest/OpenSpec-specific semantics.

1. **External references:** типизированные связи namespace + value + relation,
   уникальность активной пары в пределах project store, add/list/remove,
   lock enforcement, immutable snapshots и operation history.
2. **Review history:** append-only Review records, ссылка на существующую immutable
   task version, reviewer label, outcome, comments, actor attribution и timestamp.
3. **revision_count:** persisted task metadata; увеличивается ровно на один для
   каждой новой записи changes_requested; несколько comments в одной записи
   считаются одним review cycle; повторный идентичный review_id идемпотентен.
4. **Final commit marker:** отдельная операция, сохраняющая один текущий resolved
   full SHA независимо от обычных commit references; замена допускается после
   явного reopen и сохраняет прежнее значение в истории/версиях.

Эти возможности отсутствуют на базовом HEAD и не должны описываться как уже
реализованные.

## 4. Не является блокером MVP

- Capabilities discovery API: отсутствует; интеграция фиксирует минимальную версию
  Todoing и использует документированный API contract.
- Generic hooks/events: SQLite backend не исполняет legacy Markdown hooks;
  delivery/retry/order semantics не обещаны. Manifest выполняет собственные checks.
- Произвольная логика OpenSpec/Git в Todoing: запрещена архитектурным принципом
  независимого универсального инструмента.

## 5. Вывод

Базовая инфраструктура Todoing API v1 покрывает задачи, статусы, outcomes, версии,
историю, baseline, блокировки, зависимости, архивирование и store lifecycle.
Механически переносить старый файловый WAL-контракт Manifest в текущий Todoing
не требуется.

Интеграция Manifest блокируется не базовым API v1, а четырьмя универсальными
возможностями: external references, Review history, revision_count и final commit
marker. Они описаны в целевой спецификации и должны быть реализованы отдельным
OpenSpec change в репозитории Todoing.

После реализации расширений требуется повторная проверка исходников и тестов,
а затем сквозная приёмка Manifest ↔ Todoing ↔ OpenSpec ↔ Git.
