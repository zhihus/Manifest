# Design

## Context

Manifest — head/meta-проект типа `doc`. Программного оркестратора в
репозитории нет: оркестрацию выполняет основная сессия агента (Main
Orchestrator), исполняющая существующий OpenSpec pipeline. Todoing —
самостоятельный универсальный инструмент; он не знает о Manifest, OpenSpec и
ролях. Manifest потребляет только публичный JSON API v1 через CLI
`todoing api --json`: один JSON request через stdin, один JSON response через
stdout, диагностика в stderr.

Целевой контракт: `docs/architecture/todoing-contract.ru.md`. Расширения Todoing
API v1 (external references, Review history, revision_count, final commit
marker) реализованы и подтверждены аудитом на HEAD `d4c916e`.

## Decisions

### D1. Main Orchestrator — единственный клиент Todoing API

Main Orchestrator (основная сессия) — единственный участник, который вызывает
Todoing API и владеет lock token. Ролевые субагенты (Аналитик, Архитектор,
Планировщик, Тестировщик, Реализатор, Ревьюэр) не получают lock token и не
вызывают Todoing напрямую. Оркестратор передаёт субагенту только артефакты и
задачу, а все операции Todoing выполняет сам.

Обоснование: lock token — секрет; его распространение на субагенты создаёт
риск утечки и нарушает инварианту «никто не проверяет свою работу». Единый
клиент упрощает custody и recovery.

### D2. Один Todoing task = один OpenSpec change

Каждый OpenSpec change (каталог `openspec/changes/<id>/`) соответствует ровно
одному Todoing task. FR tasks внутри change — декомпозиция, они не
создаются отдельными задачами Todoing. Связь фиксируется external reference:
namespace `openspec.change`, value — ID каталога change, relation
`implements`, scope `project`. Для одной задачи допускается не более одной
активной ссылки этого namespace; один change ID привязан не более чем к одной
задаче.

### D3. Project Identity — UUIDv4 в `.manifest/project-id`

Project ID — стабильная строка, валидируемая Todoing как 1–128 символов без
whitespace и контрольных. Для `.manifest/project-id` используется UUIDv4
(RFC 4122): 122 бита энтропии, устойчивость к коллизиям без координации,
проходит валидацию Todoing. CLI Todoing сам генерирует `p-<hex>` (128 бит) при
отсутствии `--project-id`, поэтому UUIDv4 сопоставим по уровню энтропии.
Генерация, валидация, отсутствие файла и защита от смены — в
`design/lifecycle.md` §Project identity и спеке `todoing-project-identity`.

### D4. Lock custody с учётом блокирующего субагента

Оркестратор заблокирован во время выполнения ролевого субагента и не может
поддерживать heartbeat в этот период. Поэтому lease настраивается на покрытие
hard timeout выполнения субагента (600 с по watchdog из `AGENTS.md`) с
запасом: lease 720 с = 600 + 120. Оркестратор heartbeat'ит только когда сам
активен (между запусками субагентов, на гейтах). Recovery — явный
`task.lock.recover` после истечения lease и grace; implicit takeover
отсутствует. Подробности — в `design/lifecycle.md` §Lock custody.

### D5. Bootstrap без перезаписи

Установка Todoing выполняется пользователем; Manifest не скачивает и не
обновляет бинарный файл. `store.init` создаёт новое хранилище только когда
БД не существует; существующий `config.toml` валидируется и сохраняется;
legacy Markdown задачи и `index.json` отклоняются (требуется
`store.migrate`). Manifest не вызывает `store.init` поверх существующего store
или legacy данных. Автоматическая миграция не входит в MVP. Подробности — в
`design/bootstrap.md`.

### D6. Завершение и отмена

Успешное завершение: Review approved → acceptance checks → штатный OpenSpec
archive → Git merge по политике Manifest → `task.commit.finalize` с final
merge SHA → `task.complete` → освобождение lock. Final Commit SHA — маркер
трассируемости, а не доказательство приёмки. Отмену подтверждает только
пользователь; при подтверждении Orchestrator устанавливает outcome `cancelled`
через `task.cancel` и архивирует OpenSpec change штатным механизмом; delta
specs не вливаются в permanent specs. Подробности — в `design/lifecycle.md`
§Completion и `design/recovery.md`.

### D7. Нет общей транзакции между системами

Todoing, OpenSpec и Git не образуют транзакции. Каждое изменение —
проверяемый шаг с идемпотентным повтором или явным восстановлением. Слепые
повторы non-idempotent операций запрещены. Recovery сверяет фактические
состояния до повторения операций. Подробности — в `design/recovery.md`.

## Open questions и внешние blockers

- **Schema parity (внешний blocker, Todoing):** реализация возвращает коды
  `store_already_initialized` (exit 6) и `migration_required` (exit 2), но
  `docs/api/v1/response.schema.json` не содержит их в enum. Это не блокирует
  Manifest-side дизайн, но блокирует валидацию интеграции против схемы до
  исправления в Todoing. Зафиксировано как prerequisite интеграции.
- **Точка установки Todoing:** bootstrap не привязывается к
  `scripts/manifest-init.sh`, пока не подтверждено, что это штатная точка
  установки для пользователей, а не dev-инфраструктура.
- **Heartbeat во время субагента:** не гарантирован возможностями
  orchestration runtime; модель D4 учитывает это через lease, покрывающий
  hard timeout.