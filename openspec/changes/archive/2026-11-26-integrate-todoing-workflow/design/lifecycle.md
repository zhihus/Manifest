# Design — Жизненный цикл задачи

## Project identity

Project ID — стабильный идентификатор проекта, хранящийся в
`.manifest/project-id` и передаваемый в каждом запросе Todoing API.

- **Формат:** UUIDv4 (RFC 4122). Проходит валидацию Todoing (1–128 символов
  без whitespace и контрольных). 122 бита энтропии — устойчивость к коллизиям
  без координации.
- **Генерация:** выполняется один раз при bootstrap, если файл отсутствует.
  Генерация — атомарная запись нового UUIDv4 в `.manifest/project-id`.
- **Валидация:** при каждом запуске интеграции Manifest читает
  `.manifest/project-id` и проверяет, что значение соответствует правилам
  Project ID Todoing. При существующем store значение сверяется с
  `store.info`; несовпадение → `project_id_mismatch` → остановка.
- **Отсутствие файла:** при отсутствии `.manifest/project-id` и отсутствии
  store — bootstrap генерирует новый UUIDv4. При отсутствии файла, но
  существующем store — остановка: ID неизвестен, store не переинициализируется.
- **Защита от случайной смены:** файл `.manifest/project-id` неизменяем после
  создания. Manifest не перезаписывает его автоматически. Смена ID возможна
  только явным решением пользователя с пересозданием store. При каждом
  запуске интеграции сверка с `store.info` обнаруживает несанкционированную
  смену.

## Lock custody

Оркестратор — единственный владелец lock token. Модель учитывает блокирующее
выполнение ролевого субагента.

- **Приобретение:** Orchestrator вызывает `task.lock.acquire` для утверждённой
  задачи. Получает `owner_id`, `lock_token`, `fencing_generation`,
  `expires_at`. Token хранится только в защищённом состоянии сессии
  Orchestrator и передаётся в envelope каждого owner-запроса.
- **Heartbeat:** Orchestrator продлевает lease через `task.lock.heartbeat`
  только когда сам активен — между запусками субагентов и на гейтах. Во время
  блокирующего выполнения субагента Orchestrator заблокирован и heartbeat не
  отправляет.
- **Lease:** lease 720 с. Обоснование: hard timeout выполнения субагента —
  600 с (watchdog из `AGENTS.md`); lease 720 = 600 + 120 с запаса. Если
  Orchestrator heartbeat'ит непосредственно перед запуском субагента, lease
  переживает полный 600-секундный run субагента.
- **Освобождение:** по завершении задачи Orchestrator вызывает
  `task.lock.release`.
- **Recovery:** при истечении lease (сбой/прерывание Orchestrator) Todoing не
  передаёт владение автоматически. После истечения lease и recovery grace
  (60 с) Orchestrator вызывает `task.lock.recover`, получая новый token и
  увеличенный fencing generation. Старый владелец становится недействительным.
  После recovery Orchestrator проверяет актуальную версию задачи перед
  продолжением.

**Не утверждается**, что heartbeat каждые 60 с гарантирован во время
выполнения субагента — это невозможно в текущем orchestration runtime. Модель
обеспечивает сохранность lease через значение, покрывающее hard timeout.

## Task state

Один OpenSpec change = один Todoing task.

- **Создание:** пользователь создаёт задачу или Аналитик предлагает её в
  Backlog. Manifest создаёт задачу через `task.create` со статусом `backlog` и
  фиксирует external reference: namespace `openspec.change`, value — ID
  каталога change, relation `implements`, scope `project`.
- **Утверждение:** переход `backlog → ready` утверждает только пользователь.
  Агент не считает задачу утверждённой самостоятельно. После утверждения
  Manifest при необходимости фиксирует baseline через `task.version.approve`.
- **Выполнение:** Orchestrator приобретает lock, переводит задачу в
  `in_progress` и выполняет пайплайн. Статусы: `backlog → ready → in_progress
  → review → verified → completed`; из `review` — в `verified` при одобрении
  или обратно в `in_progress` при замечаниях.
- **External reference:** не более одной активной ссылки namespace
  `openspec.change` на задачу; один change ID привязан не более чем к одной
  задаче. При отмене ссылка сохраняется для аудита.

## Review cycle

- **Передача:** перед передачей результата Orchestrator переводит задачу в
  `review` и передаёт Reviewer артефакты через собственный workflow.
- **Запись Review:** Manifest вызывает `task.review.add` с `review_id`,
  `version_no` проверяемой версии, `reviewer` label, `outcome`
  (`approved`/`changes_requested`) и упорядоченным массивом `comments`.
  `actor_id` envelope фиксирует агента Reviewer.
- **Одобрение:** Todoing сохраняет запись Review с outcome `approved`; Manifest
  переводит задачу в `verified`.
- **Замечания:** Todoing атомарно сохраняет запись с outcome
  `changes_requested` и увеличивает `revision_count` ровно на один; Manifest
  возвращает задачу в `in_progress`.
- **Идемпотентность:** повторный `review_id` с идентичным payload — no-op;
  тот же ID с иным payload → `review_id_conflict`. Review не меняет workflow
  status.

## Completion

Успешное завершение (последовательность проверяемых шагов):

1. Статус `verified` достигнут (Review approved).
2. Orchestrator выполняет acceptance checks согласованности Todoing ↔
   OpenSpec ↔ Git.
3. Штатный OpenSpec archive: delta specs вливаются в permanent specs, change
   перемещается в `openspec/changes/archive/`.
4. Git merge согласно политике Manifest (ветки, review, merge).
5. `task.commit.finalize` с final merge SHA — маркер трассируемости.
6. `task.status.set` → `completed` — терминальный переход. Статус `completed`
   в `config.toml` отображён на outcome `completed`, поэтому переход сам
   устанавливает и `status_id = completed`, и `outcome = completed`,
   делая задачу терминальной.
7. Освобождение lock через `task.lock.release`.

**Семантика терминального вызова.** Переход в статус, отображённый на outcome
`completed`, сам устанавливает этот outcome; отдельный вызов `task.complete`
в success-пути не выполняется. Повторный `task.complete` после такого
перехода отклоняется как `task_terminal` (outcome уже установлен).
`task.complete` — альтернативный терминальный путь, который устанавливает
только outcome без смены статуса; он несовместим с одновременным переходом в
`completed` и в данной модели не используется.

Final Commit SHA — маркер трассируемости, а не доказательство успешной
приёмки. Наличие commit reference само по себе не означает завершение.

## Cancellation

1. Любой агент может рекомендовать отмену с обоснованием.
2. Отмену подтверждает только пользователь.
3. После подтверждения Orchestrator вызывает `task.cancel` с причиной
   (outcome `cancelled`, workflow status не меняется). `task.cancel`
   устанавливает терминальный outcome; повторный вызов отклоняется как
   `task_terminal`.
4. Orchestrator архивирует OpenSpec change штатным механизмом Archive; delta
   specs не вливаются в permanent specs.
5. Orchestrator освобождает lock через `task.lock.release`. Release допустим
   после установки терминального outcome: `task.lock.release` проверяет только
   lock record (state, owner, token, expiry), а не outcome задачи. Если ответ
   на release потерян — проверить владение через `task.lock.heartbeat`
   (успех → повторить release; `stale_lock` → token больше не действителен:
   lock мог быть освобождён либо перехвачен через recovery, старый владелец не
   выполняет дальнейших операций с этим token; `lock_expired` → явный
   recovery после grace при необходимости).
6. External reference сохраняется для аудита.

Отмена не выполняется только переводом статуса или архивированием задачи:
outcome и OpenSpec archive фиксируются отдельными действиями. Повторное
открытие отменённой задачи требует явного решения и `task.reopen`.