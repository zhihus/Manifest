# Аудит реализации Todoing — сверка с требованиями Manifest

**Статус:** аналитический отчёт (read-only аудит), не решение и не изменение контракта.
**Дата аудита:** 2026-11-23.
**Режим аудита:** только чтение исходников, тестов и документации; в ходе аудита файлы Todoing и Manifest не изменялись, полный набор тестов не запускался. Публикация отчёта выполнена отдельным коммитом после аудита.

## 1. Объекты и метаданные

| Поле | Значение |
| --- | --- |
| Репозиторий Todoing | `C:\WorkProjects\todoing-x` |
| Ветка Todoing | `main` |
| **HEAD Todoing (объект аудита)** | `947048d3864e99c7d0dfcc48889a084e0a99e42d` |
| HEAD Todoing (рабочее дерево на момент аудита) | `a0088362f030ab226c50cc192212e9ba5416babf` |
| Репозиторий Manifest | `C:\WorkProjects\Manifest` |
| Ветка Manifest | `feature/todoing-contract-spec` |
| **HEAD Manifest** | `7c8a30f076cecc75393cb63a29c69628cfa7064b` |

> Аудит выполнен по извлечённой копии дерева Todoing `947048d` (через `git archive`) в
> `todoing-x/temp/audit-947048d/`, так как рабочее дерево `todoing-x` находилось на
> `a008836`. Все цитаты путей ниже — относительно корня дерева `947048d`.

**Сопоставляемые требования Manifest:** `docs/architecture/architecture-brief.ru.md`,
`docs/architecture/architecture-decisions.ru.md`, `docs/architecture/todoing-contract.ru.md`.
**Границы ответственности:** `todoing-x/docs/integrations/consumer-contract.md` (дерево
`947048d`).

## 2. Ключевой контекст (факт, не вывод)

Реализация Todoing на `947048d` — это **версионируемый JSON API v1 поверх SQLite**
(`src/api.rs`, `src/storage/*`). Целевой контракт Manifest (`todoing-contract.ru.md`)
описывает **файловый WAL-дизайн** (файлы задач, append-only WAL, операции `contract`/
capabilities, `review-note`/`review_history`/`revision_count`, `openspec bind/unbind`,
`final-commit`). Реализация и целевой контракт расходятся по модели хранения и по набору
операций. Это расхождение зафиксировано как факт, а не как дефект.

## 3. Подтверждённые факты реализации

Каждый факт подтверждён конкретным файлом исходников, спецификацией или тестом Todoing
(пути — в дереве `947048d`).

### 3.1 JSON API v1 (envelope, операции, ошибки, project_id, actor_id)

- **Факт:** единый JSON-запрос на stdin → единый JSON-ответ на stdout; diagnostics на stderr;
  ненулевой exit code при ошибке. Envelope `Request` с `#[serde(deny_unknown_fields)]`:
  `api_version, request_id, project_id, actor_id, operation, args, lock_token`.
- **Факт:** 28 операций в диспетчере `OPERATIONS` (`src/api.rs:263`):
  `store.init/info/verify/migrate/snapshot`; `task.create/list/get/archive/restore/update/
  status.set/complete/cancel/reopen`; `task.label.add/remove`; `task.commit.add`;
  `task.dependency.add/remove/list`; `task.history.list`; `task.version.list/get/compare/
  approve`; `task.lock.acquire/heartbeat/release/recover`.
- **Факт:** `project_id` сверяется с метаданными хранилища (несовпадение →
  `project_id_mismatch`); `actor_id` обязателен для чтений и записей и является атрибуцией,
  не аутентификацией.
- **Факт:** стабильные коды ошибок и коды выхода: 2 (invalid_request/
  unsupported_api_version/project_id_mismatch/config_invalid/migration_required), 3
  (task_not_found/version_not_found/dependency_not_found), 4 (task_terminal/task_archived/
  task_locked/lock_expired/stale_lock/invalid_status_transition/dependency_cycle), 5
  (io_error/store_corrupt/store_busy/history_record_failed), 6 (migration_conflict/
  store_already_initialized), 70 (other).
- **Подтверждение:** `src/api.rs` (Request, OPERATIONS, `api_exit_code`);
  `docs/api/v1/operations.md` §1, §9; `tests/cli.rs::json_interface_covers_task_reads_and_
  mutations`, `json_api_store_init_creates_a_project_store`,
  `json_api_transport_covers_migration_snapshot_response_and_exit_contract`;
  `consumer-contract.md` §3.

### 3.2 Статусы и переходы (конфигурация, валидация, изменение конфигурации)

- **Факт:** статусы и переходы настраиваются в `.todoing/config.toml` (TOML,
  `format_version=1`); по умолчанию `todo/in_progress/done`. `validate()` проверяет
  `format_version`, непустые статусы, lock-настройки (lease≥60с, heartbeat>0 и <lease/3),
  валидность и уникальность ID, ≥1 enabled статус, что transitions ссылаются на существующие
  и enabled статусы.
- **Факт:** `config_revision` = SHA-256 сериализованной конфигурации фиксируется в истории
  при смене статусов.
- **Подтверждение:** `src/config/mod.rs` (ProjectConfig, validate);
  `docs/api/v1/operations.md` §3 (task.status.set, task.create, task.reopen);
  `src/storage/status_workflow_tests.rs::configured_transition_changes_status_and_records_
  config_revision`, `forbidden_transition_is_rejected_and_recorded_without_mutation`,
  `disabled_status_cannot_be_assigned_to_a_task`; `consumer-contract.md` §4.

### 3.3 История и версии (атомарность, полнота снимков, approve/baseline)

- **Факт:** каждое успешное сохранение состояния задачи создаёт новую неизменяемую версию
  задачи и событие истории в одной транзакции; no-op (без изменения состояния) не создаёт
  версию. Версии и история защищены DB-триггерами `task_versions_no_update/no_delete`,
  `operation_history_no_update/no_delete`.
- **Факт:** `approve_baseline` (`ON CONFLICT(task_id) DO UPDATE`) устанавливает утверждённую
  baseline-версию без создания новой версии, с записью в историю; `compare_versions` даёт
  field-level diff.
- **Подтверждение:** `src/storage/task_repository.rs` (create, persist_task_change,
  same_task_state, approve_baseline, compare_versions);
  `migrations/0001_initial.sql` (триггеры); `docs/api/v1/operations.md` §6, §8;
  `src/storage/task_history_tests.rs::create_writes_initial_immutable_version_and_history_
  atomically`, `no_op_update_does_not_create_redundant_version_or_history`,
  `baseline_approval_references_a_version_of_the_same_task_and_is_audited`,
  `version_and_history_rows_are_immutable_at_database_level`.

### 3.4 Блокировки (изоляция чтения/записи, heartbeat, recovery, fencing)

- **Факт:** эксклюзивная блокировка с 256-битным токеном (в БД хранится только SHA-256
  хэш, сравнение `constant_time_equal`); `acquire` в EXCLUSIVE-транзакции; `heartbeat`
  продлевает лиз только при совпадении owner+token+generation и не для истёкшей; `release`
  сохраняет строку со `state=released` (generation не сбрасывается); `recover` — только после
  expiry+recovery_grace, создаёт нового owner/token, инкрементирует generation.
- **Факт:** изоляция чтения — все заблокированные задачи исключаются из list/search;
  `task.get` доступен только владельцу с валидным токеном; зависимости заблокированных задач
  показываются с null-полями + `locked=true`. Автоматического захвата нет.
- **Подтверждение:** `src/storage/lock.rs` (LockGrant, generate_token, token_hash,
  constant_time_equal, acquire, heartbeat, release, recover, check_lock_access);
  `docs/api/v1/operations.md` §7; `src/storage/lock_tests.rs::acquire_returns_one_time_token_
  and_persists_only_its_hash`, `recovery_requires_expiry_and_grace_and_fences_the_previous_
  owner`, `repository_enforces_lock_for_reads_writes_history_and_version_access`;
  `consumer-contract.md` §5.

### 3.5 Зависимости (проверка циклов, атомарность)

- **Факт:** self-зависимость запрещена (CHECK `task_id <> depends_on_task_id`); прямые и
  косвенные циклы отклоняются рекурсивным CTE `WITH RECURSIVE reachable`; проверка цикла и
  вставка ребра — в одной транзакции.
- **Подтверждение:** `src/storage/task_repository.rs` (add_dependency);
  `migrations/0001_initial.sql` (CHECK); `docs/api/v1/operations.md` §5;
  `src/storage/dependency_tests.rs::self_dependency_is_rejected_and_recorded`,
  `indirect_dependency_cycle_is_rejected`,
  `dependency_state_reports_archived_and_locked_references_without_leaking_locked_fields`.

### 3.6 Archive/restore и запрет физического удаления

- **Факт:** archive/restore идемпотентны (`no_op=true`, без версии); архивные задачи
  read-only до восстановления (`task_archived`); нет каскада на зависимые; физическое
  удаление запрещено `ON DELETE RESTRICT` FK и триггером `tasks_no_delete`.
- **Подтверждение:** `src/storage/task_repository.rs` (set_archive_state);
  `migrations/0001_initial.sql`, `migrations/0002_task_archive.sql` (триггеры, RESTRICT);
  `docs/api/v1/operations.md` §3 (task.archive, task.restore);
  `tests/cli.rs::delete_always_rejects_physical_deletion_without_reading_stdin`,
  `sqlite_cli_archive_restore_is_explicit_non_destructive_and_versioned`;
  `src/storage/task_repository_tests.rs::archive_and_restore_preserve_identity_outcome_and_
  relationships`, `archived_tasks_are_read_only_until_restored`.

### 3.7 Git commit refs

- **Факт:** `task.commit.add` выполняет `git rev-parse --verify --end-of-options <rev>^{commit}`,
  валидирует 40/64 hex SHA и хранит только Git SHA; это «traceability metadata, not proof of
  completion». Произвольные внешние ссылки (URL, work-item ID, OpenSpec change ID) не
  поддерживаются.
- **Подтверждение:** `src/api.rs` (task.commit.add); `migrations/0001_initial.sql`
  (CHECK length IN (40,64) AND hex); `docs/api/v1/operations.md` §4;
  `openspec/specs/git-commit-references/spec.md`; `tests/cli.rs::commit_links_store_full_sha_
  and_deduplicate_resolved_refs`; `consumer-contract.md` §6.

### 3.8 Миграция, verify, snapshot

- **Факт:** `store.migrate` — non-destructive импорт legacy, отклоняет существующую БД,
  поддерживает `dry_run`, staging store, source hashes. `store.verify` — сверка project_id,
  `validate_schema`, `integrity_check`, `foreign_key_violations`. `store.snapshot` — SQLite
  Online Backup API, отклоняется при любой активной task lock, destination не должен
  резолвиться в активную БД, существующие файлы не перезаписываются без `overwrite=true`,
  snapshot переоткрывается и проходит integrity-check перед успехом.
- **Подтверждение:** `src/migration.rs` (migrate); `src/storage/store.rs` (verify, snapshot);
  `src/initialization.rs` (initialize); `docs/api/v1/operations.md` §2;
  `tests/cli.rs::json_api_transport_covers_migration_snapshot_response_and_exit_contract`;
  `consumer-contract.md` §6.

## 4. Выводы (полностью / частично / отсутствует)

| # | Область | Требование Manifest | Вывод |
| --- | --- | --- | --- |
| 1 | JSON API v1 | Версионируемый контракт, project_id, actor_id, стабильные коды ошибок/выхода | **Полностью** |
| 2 | Статусы и переходы | Настраиваемые статусы, валидация, фиксация ревизии конфигурации | **Полностью** |
| 3 | История и версии | Полная неизменяемая история, версии, утверждённая baseline | **Полностью** |
| 4 | Блокировки | Эксклюзивная блокировка, изоляция чтения, recovery, fencing | **Полностью** |
| 5 | Зависимости | Проверка циклов, атомарность | **Полностью** |
| 6 | Archive/restore | Запрет физического удаления, archive/restore, read-only архив | **Полностью** |
| 7 | Git commit refs | Связи с commit/merge | **Частично** — Git SHA да, произвольные внешние ссылки нет |
| 8 | Review history / revision_count | review-note, review_history, revision_count | **Отсутствует** |
| 9 | Hooks/events | Универсальные необязательные hooks | **Частично** — legacy CLI hooks да, SQLite backend нет, event API отложен |
| 10 | Discovery (capabilities) | contract/capabilities для определения возможностей без пробных вызовов | **Отсутствует** |
| 11 | Миграция/verify/snapshot | Миграция, verify, snapshot | **Полностью** |

Каждый вывод подкреплён фактами из раздела 3 с указанием подтверждающих файлов.

## 5. Границы ответственности Todoing и Manifest

Зафиксировано согласно `todoing-x/docs/integrations/consumer-contract.md` (дерево `947048d`).

**Todoing предоставляет:** локальное SQLite-хранилище задач на проект; настраиваемые статусы
и разрешённые переходы; состояние задач, зависимости, неизменяемые версии, append-only
историю операций, утверждённые baseline; эксклюзивные блокировки с лизами и fencing
generation; CLI и версионируемый JSON API v1; Git commit references как метаданные
прослеживаемости; верифицированные SQLite-снапшоты.

**Потребитель (Manifest) владеет:** стабильной идентичностью проекта и выбором проекта;
оркестрацией агентов, назначением ролей, последовательностью, выбором модели; утверждением
пользователя и проектной политикой завершения; workflow OpenSpec и политикой Git
ветка/коммит/ревью; проверками согласованности между Todoing, OpenSpec, Git и другими
компонентами; аутентификацией акторов и безопасным хранением lock-токенов; местом,
хранением и репликацией снапшотов.

**Принцип:** Todoing не парсит OpenSpec, не определяет Git-workflow, не аутентифицирует
акторов и не применяет ролевую политику потребителя. Интеграции опциональны; потребитель
запускает проверки только для подключённых и сконфигурированных компонентов.
Конкретное поведение, специфичное для потребителя, не должно добавляться в ядро Todoing
(`consumer-contract.md` §1, §8).

## 6. Специальный фокус: OpenSpec/Git references, Reviewer remarks, revision_count,
hooks/events, capabilities discovery

### 6.1 OpenSpec/Git references

- **Git:** выражается через `task.commit.add` (только Git SHA, `src/api.rs`,
  `openspec/specs/git-commit-references/spec.md`). Покрывает связь с итоговым commit/merge.
- **OpenSpec:** выделенного механизма **нет**. `consumer-contract.md` §8 явно относит
  «Any relationship between Todoing task IDs and external specification/work-item
  identifiers» к нерешённым решениям потребителя. Нативной привязки OpenSpec change ↔
  Todoing task нет; обойти можно через labels или commit refs как конвенцию, но это не
  выделенная сущность.
- **Вывод:** OpenSpec-связи либо хранятся в Manifest, либо требуют расширения Todoing
  механизмом внешних ссылок.

### 6.2 Reviewer remarks

- Выделенного механизма **нет**. Нет операций `review-note`/`review_history`, нет структуры
  «замечание → статус → привязка к версии → история». Замечания можно «упаковать» в
  `task.update` (body) или labels, но это не выделенный механизм.
- **Вывод:** для полноценного review-цикла Manifest либо хранит review-историю в себе, либо
  требует расширения Todoing `review-note`/`review_history`.

### 6.3 revision_count

- Отдельного поля **нет**. `revision_count` выводимо как производное из `task.version.list`
  (количество версий). Это не выделенная сущность, а производный счётчик.
- **Вывод:** достаточно для подсчёта, но не заменяет выделенное поле, если требуется
  стабильный идентификатор ревизии.

### 6.4 Hooks/events

- Legacy CLI hooks существуют в `src/main.rs` (`.todoing/hooks/`: `before-done-git`,
  `before-done-openspec`, `before-done`, on-create); отсутствие hook = no-op.
- **SQLite backend не выполняет** legacy Markdown completion hooks; универсальный lifecycle
  event API **отложен** (deferred); delivery/ordering/retry/failure-семантика не обещаны
  (`consumer-contract.md` §7).
- **Вывод:** consumer не должен полагаться на hooks Todoing для корректности; он может
  запускать собственные проверки до/после операций Todoing.

### 6.5 Capabilities discovery

- Операции `contract`/capabilities **нет**. `store.info` возвращает только `project_id`,
  `schema_version`, `api_version`, `task_count`. Нет способа получить список операций, полей,
  статусов или возможностей без пробных вызовов.
- **Вывод:** discovery отсутствует; потребителю приходится опираться на нормативный
  документ `docs/api/v1/operations.md`, а не на runtime-запрос возможностей.

## 7. Устаревшие утверждения в документах Manifest (зафиксированы, не исправлены)

Ниже — утверждения в документах Manifest, которые не соответствуют реализации Todoing на
`947048d`. Они **зафиксированы как устаревшие**, но в соответствии с условиями аудита **не
исправлены**.

1. **`architecture-decisions.ru.md` §4:** «НР (не реализовано в todoing-x): история, версии,
   зависимости, блокировки, архивирование, новый версионируемый API, Project ID. Текущая
   реализация — прототип.» — **Устарело.** На `947048d` история, версии, зависимости,
   блокировки, архивирование, версионируемый JSON API v1 и Project ID реализованы (разделы
   3.3–3.6, 3.1). Запись сделана на момент, когда todoing-x был на `a008836`.
2. **`todoing-contract.ru.md`:** целевой контракт описывает файловый WAL-дизайн (файлы задач,
   append-only WAL, операции `contract`/`review-note`/`openspec bind`/`final-commit`).
   Реализация на `947048d` — SQLite-дизайн с иным набором операций. Контракт описывает
   целевое состояние, а не текущую реализацию; расхождение зафиксировано, но контракт не
   изменялся.
3. **`architecture-brief.ru.md` §7 (требования к Todoing):** часть требований (например,
   discovery/capabilities, review-механизмы) не реализована в `947048d` и не реализована в
   целевом контракте как выделенные сущности; см. разделы 6.2, 6.3, 6.5.

## 8. Рекомендации

Ниже — рекомендации для Manifest (не решения, не изменения контракта).

1. **Discovery:** если Manifest требует определять поддерживаемые возможности без пробных
   вызовов, это требует либо новой операции `contract`/capabilities в Todoing, либо
   нормативного документа, на который опирается потребитель. На `947048d` только второе
   (`docs/api/v1/operations.md`).
2. **OpenSpec-связи:** решение «Task ID ↔ внешний идентификатор» передано потребителю
   (`consumer-contract.md` §8). Manifest должен определить, где хранить привязку
   (в Manifest или через labels как конвенцию), либо потребовать расширения Todoing
   механизмом внешних ссылок.
3. **Reviewer remarks / revision_count:** для полноценного review-цикла Manifest либо хранит
   review-историю в себе, либо требует расширения Todoing `review-note`/`review_history`/
   `revision_count`. `revision_count` на `947048d` лишь выводимо из `task.version.list`.
4. **Hooks/events:** consumer не должен полагаться на hooks Todoing для корректности
   (`consumer-contract.md` §7). Если требуется универсальный event-механизм, это отдельное
   проектирование (сейчас отложено).
5. **Синхронизация документов:** устаревшие утверждения в `architecture-decisions.ru.md` §4
   и расхождение целевого контракта с реализацией следует согласовать в отдельном решении,
   не изменяя текущий аудит.

## 9. Ограничения аудита

- В ходе самого аудита в репозиториях Manifest и Todoing не изменялись файлы, коммиты не создавались, push не выполнялся. Публикация этого отчёта в Manifest выполнена отдельно после аудита коммитом `48b404a1889020c63ddd233d05ca4236b1c9d44c`.
- Полный набор тестов не запускался; поведение подтверждено чтением исходников, тестов и
  документации.
- Аудит сверен с HEAD Todoing `947048d` и HEAD Manifest `7c8a30f`; при изменении HEAD
  выводы могут устареть.
- Контракт, architecture brief, decisions и roadmap не изменялись; Todoing не изменялся.