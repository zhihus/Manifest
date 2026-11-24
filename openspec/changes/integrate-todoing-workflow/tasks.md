# Tasks: integrate-todoing-workflow

> Реализация интеграции выполняется отдельным решением после одобрения
> данного change. Задачи ниже — декомпозиция для последующей реализации;
> они не выполняются в рамках этого change.
>
> Архитектурная граница (D9): Manifest — head/meta-проект типа `doc`,
> программного оркестратора нет. Реализация интеграции — документируемая
> процедура, которую Main Orchestrator выполняет, вызывая публичный JSON API
> v1 Todoing через CLI `todoing api --json`. Артефакты реализации:
> bootstrap-файлы (`.manifest/project-id`, `.todoing/config.toml`) и
> workflow-документация (`workflow/README.ru.md`). Подробности — в
> `design.md` D9.

## 1. Project Identity

- [ ] fr-1.1-generate-project-id-file
  Создайте файл `.manifest/project-id`: при отсутствии файла сгенерируйте
  UUIDv4 (RFC 4122) и запишите его атомарно (write-to-temp + rename).
  Валидируйте значение по правилам Todoing Project ID: 1–128 символов, без
  whitespace и контрольных. Формат: одна строка, без trailing newline.
  Stop: файл существует, содержит валидный UUIDv4 (8-4-4-4-12 hex) и
  проходит валидацию Todoing Project ID.
  Maps to scenarios: `todoing-project-identity` §Генерация Project ID.

- [ ] fr-1.2-validate-project-id-on-start
  В `workflow/README.ru.md` (секция «Bootstrap») опишите процедуру: при
  каждом старте интеграции Main Orchestrator читает `.manifest/project-id`,
  валидирует значение (UUIDv4, 1–128 символов, без whitespace) и, если store
  существует, сверяет его с `store.info`. При несоответствии — остановка с
  диагностикой `project_id_mismatch` и сообщением пользователю.
  Stop: процедура описана в `workflow/README.ru.md` и покрывает четыре
  комбинации presence/absence файла и presence/absence store.
  Maps to scenarios: `todoing-project-identity` §Валидация Project ID.

- [ ] fr-1.3-protect-project-id-from-change
  В `workflow/README.ru.md` (секция «Bootstrap») зафиксируйте инвариант:
  `.manifest/project-id` никогда не перезаписывается автоматически после
  создания. Изменение возможно только явным решением пользователя с
  пересозданием store. В bootstrap-процедуре нет кода, который перезаписывает
  существующий файл.
  Stop: в описанной bootstrap-процедуре нет пути автоматической перезаписи
  `.manifest/project-id`.
  Maps to scenarios: `todoing-project-identity` §Защита Project ID.

## 2. Store Bootstrap

- [ ] fr-2.1-check-todoing-availability
  В `workflow/README.ru.md` (секция «Bootstrap») опишите проверку: Main
  Orchestrator выполняет `todoing api --json` с тестовым запросом
  (`store.info`). Если бинарник отсутствует или не отвечает — остановка с
  диагностикой «Todoing not available; install manually». Установка
  выполняется пользователем отдельно.
  Stop: в описанной процедуре есть явная проверка доступности и явный
  стоп-сигнал при недоступности.
  Maps to scenarios: `todoing-store-bootstrap` §Проверка доступности Todoing.

- [ ] fr-2.2-write-config-toml-without-overwrite
  Создайте файл `.todoing/config.toml` (при отсутствии): шесть статусов
  (`backlog`, `ready`, `in_progress`, `review`, `verified`, `completed`),
  отображение `completed` → outcome `completed`, transitions по модели
  `backlog → ready → in_progress → review → verified → completed`.
  Секция `locking`: `lease_seconds = 720`, `heartbeat_seconds = 60`
  (валидация Todoing требует `heartbeat*3 < lease`, т.е. heartbeat < 240 с;
  60 с проходит). Атомарная запись (write-to-temp + rename) только при
  отсутствии файла. Существующий файл валидируется: при несовместимости
  (отсутствует статус `completed` или неверное отображение outcome) —
  остановка bootstrap.
  Stop: существующий `config.toml` никогда не перезаписывается;
  несовместимый конфиг останавливает bootstrap.
  Maps to scenarios: `todoing-store-bootstrap` §Конфигурация без перезаписи.

- [ ] fr-2.3-call-store-init
  В `workflow/README.ru.md` (секция «Bootstrap») опишите вызов `store.init`
  с Project ID из `.manifest/project-id`. Операция создаёт новое хранилище
  только когда БД не существует. При существующем store — `store.init` не
  вызывается (защита от перезаписи).
  Stop: в описанной процедуре `store.init` не вызывается поверх
  существующего store или legacy данных.
  Maps to scenarios: `todoing-store-bootstrap` §Инициализация store.

- [ ] fr-2.4-verify-store
  В `workflow/README.ru.md` (секция «Bootstrap») опишите верификацию: после
  `store.init` Main Orchestrator вызывает `store.info` и `store.verify`.
  При несоответствии — остановка с диагностикой.
  Stop: верификация подтверждает, что store инициализирован и согласован.
  Maps to scenarios: `todoing-store-bootstrap` §Проверка хранилища.

## 3. Lock Custody

- [ ] fr-3.1-acquire-lock-for-approved-task
  В `workflow/README.ru.md` (секция «Lock custody») опишите: Main Orchestrator
  вызывает `task.lock.acquire` для одобренной задачи, получает `owner_id`,
  `lock_token`, `fencing_generation`, `expires_at` и хранит token в
  защищённом состоянии сессии. Token передаётся в envelope каждого owner
  request. Ролевые субагенты не получают lock token и не вызывают Todoing.
  Stop: в описанной процедуре token хранится и используется в envelopes;
  ролевые субагенты не получают token.
  Maps to scenarios: `todoing-lock-custody` §Приобретение lock.

- [ ] fr-3.2-heartbeat-when-orchestrator-active
  В `workflow/README.ru.md` (секция «Lock custody») опишите: Main Orchestrator
  продлевает lease через `task.lock.heartbeat` только когда сам активен
  (между запусками субагентов, на гейтах). Во время блокирующего выполнения
  субагента heartbeat не отправляется. Heartbeat выполняется непосредственно
  перед запуском субагента, чтобы lease покрывал его hard timeout.
  Stop: в описанной процедуре heartbeat отправляется только когда Orchestrator
  активен; heartbeat выполняется перед запуском субагента, а не во время него.
  Maps to scenarios: `todoing-lock-custody` §Heartbeat только при активности Orchestrator.

- [ ] fr-3.3-configure-lease-to-cover-hard-timeout
  В `workflow/README.ru.md` (секция «Lock custody») зафиксируйте: lease = 720 с
  (600 с hard timeout субагента по watchdog из `AGENTS.md` + 120 с запас).
  Lease покрывает полный прогон субагента, если Orchestrator heartbeat'ит
  непосредственно перед запуском.
  Stop: значение lease в workflow-документе равно 720 с и обосновано
  (600 + 120).
  Maps to scenarios: `todoing-lock-custody` §Lease покрывает hard timeout.

- [ ] fr-3.4-release-lock-on-completion
  В `workflow/README.ru.md` (секция «Completion») опишите: Main Orchestrator
  вызывает `task.lock.release` после `task.status.set` → `completed`
  (терминальный переход) и после отмены (после `task.cancel` и OpenSpec
  archive). Повторный `task.lock.release` не идемпотентен — возвращает
  `stale_lock`. Если ответ на release потерян, Orchestrator проверяет
  владение через `task.lock.heartbeat`: успех → повторить release;
  `stale_lock` → token больше не действителен (lock мог быть освобождён либо
  перехвачен через recovery), старый владелец не выполняет дальнейших операций
  с этим token; `lock_expired` → явный recovery после grace при
  необходимости.
  Stop: в описанной процедуре release вызывается после `task.status.set` →
  `completed` и после отмены; повтор release выполняется только после
  подтверждения владения heartbeat'ом.
  Maps to scenarios: `todoing-lock-custody` §Освобождение lock.

- [ ] fr-3.5-recover-lock-after-lease-expiry
  В `workflow/README.ru.md` (секция «Recovery») опишите: после истечения lease
  и recovery grace (60 с) Main Orchestrator вызывает `task.lock.recover`,
  получает новый token и увеличенный fencing generation. Старый token
  становится недействительным (`stale_lock` на любую операцию). После
  recovery Orchestrator проверяет текущую версию задачи перед продолжением.
  Конкурирующие recover атомны: только первый succeeds (Exclusive transaction
  + CAS на `fencing_generation`); второй получает `task_locked`.
  Stop: recovery описан явно; старый token не используется после recovery;
  конкурентность учтена.
  Maps to scenarios: `todoing-lock-custody` §Recovery после истечения lease.

## 4. Task State and External Reference

- [ ] fr-4.1-create-task-and-external-reference
  В `workflow/README.ru.md` (секция «Task state») опишите: Main Orchestrator
  создаёт Todoing task со статусом `backlog` и записывает external reference:
  namespace `openspec.change`, value — ID каталога change, relation
  `implements`, scope `project`.
  Stop: в описанной процедуре задача создаётся с external reference.
  Maps to scenarios: `todoing-task-state` §Создание задачи и external reference.

- [ ] fr-4.2-approve-backlog-to-ready-transition
  В `workflow/README.ru.md` (секция «Task state») опишите: переход
  `backlog → ready` подтверждается только пользователем. После одобрения
  Manifest фиксирует baseline через `task.version.approve` при необходимости.
  Stop: в описанной процедуре переход не выполняется без подтверждения
  пользователя.
  Maps to scenarios: `todoing-task-state` §Одобрение перехода backlog → ready.

- [ ] fr-4.3-enforce-external-reference-uniqueness
  В `workflow/README.ru.md` (секция «Task state») зафиксируйте: не более одной
  активной ссылки `openspec.change` на задачу и не более одной задачи на
  change ID. При отмене ссылка сохраняется для аудита.
  Stop: ограничения уникальности описаны; ссылка переживает отмену.
  Maps to scenarios: `todoing-task-state` §Уникальность external reference.

## 5. Review Cycle

- [ ] fr-5.1-hand-off-to-review
  В `workflow/README.ru.md` (секция «Review cycle») опишите: перед передачей
  результата Main Orchestrator переводит задачу в `review` и передаёт
  артефакты Reviewer через собственный workflow.
  Stop: в описанной процедуре задача в `review` до начала работы Reviewer.
  Maps to scenarios: `todoing-review-cycle` §Передача на review.

- [ ] fr-5.2-record-review
  В `workflow/README.ru.md` (секция «Review cycle») опишите: Manifest вызывает
  `task.review.add` с `review_id`, `version_no`, меткой `reviewer`, `outcome`
  (`approved`/`changes_requested`) и упорядоченным массивом `comments`.
  Envelope `actor_id` фиксирует агента Reviewer.
  Stop: запись review хранится с правильным outcome и comments.
  Maps to scenarios: `todoing-review-cycle` §Запись review.

- [ ] fr-5.3-handle-approval
  В `workflow/README.ru.md` (секция «Review cycle») опишите: при `approved`
  Todoing хранит запись review, а Manifest переводит задачу в `verified`.
  Stop: после approved review задача в `verified`.
  Maps to scenarios: `todoing-review-cycle` §Обработка approval.

- [ ] fr-5.4-handle-changes-requested
  В `workflow/README.ru.md` (секция «Review cycle») опишите: при
  `changes_requested` Todoing атомарно хранит запись и увеличивает
  `revision_count` ровно на единицу; Manifest возвращает задачу в
  `in_progress`.
  Stop: `revision_count` увеличивается на единицу, задача в `in_progress`.
  Maps to scenarios: `todoing-review-cycle` §Обработка замечаний.

## 6. Completion and Cancellation

- [ ] fr-6.1-complete-the-task
  В `workflow/README.ru.md` (секция «Completion») опишите: после `verified`,
  acceptance checks, OpenSpec archive и Git merge Main Orchestrator вызывает
  `task.commit.finalize` с final merge SHA, затем `task.status.set` →
  `completed` (терминальный переход, сам устанавливает outcome `completed`),
  затем `task.lock.release`. Отдельный вызов `task.complete` в success path
  не выполняется; повторный `task.complete` после `completed` отклоняется как
  `task_terminal`.
  Stop: задача имеет статус `completed` и outcome `completed`, final commit
  SHA записан, lock освобождён.
  Maps to scenarios: `todoing-completion-recovery` §Успешное завершение.

- [ ] fr-6.2-cancel-the-task
  В `workflow/README.ru.md` (секция «Completion») опишите: после
  подтверждения пользователем Main Orchestrator вызывает `task.cancel` с
  причиной (outcome `cancelled`, терминальный; повтор → `task_terminal`),
  архивирует OpenSpec change штатным механизмом (delta specs не вливаются)
  и освобождает lock через `task.lock.release`. External reference
  сохраняется для аудита.
  Stop: задача имеет outcome `cancelled`, change архивирован без слияния
  delta specs, lock освобождён, reference сохранён.
  Maps to scenarios: `todoing-completion-recovery` §Отмена.

## 7. Recovery

- [ ] fr-7.1-reconcile-states-before-retry
  В `workflow/README.ru.md` (секция «Recovery») опишите: перед повтором любой
  операции Main Orchestrator читает фактическое состояние Todoing, OpenSpec и
  Git и определяет, какие операции ещё не выполнены. Слепые повторы
  non-idempotent операций запрещены.
  Stop: в описанной процедуре нет повора операции без шага сверки состояний.
  Maps to scenarios: `todoing-completion-recovery` §Recovery после частичного сбоя.

- [ ] fr-7.2-handle-partial-failure-scenarios
  В `workflow/README.ru.md` (секция «Recovery») опишите recovery для сценариев
  S1–S5 из `design/recovery.md`: (S1) между OpenSpec archive и Git merge;
  (S2) между Git merge и `task.commit.finalize`; (S3) между переходом в
  `completed` и освобождением lock; (S4) истечение lease во время субагента;
  (S5) отмена. Каждый сценарий — идемпотентный повтор или явное восстановление
  с предварительной сверкой состояний.
  Stop: каждый сценарий S1–S5 имеет описанный путь recovery, который не
  повторяет non-idempotent операции слепо.
  Maps to scenarios: `todoing-completion-recovery` §Recovery scenarios.