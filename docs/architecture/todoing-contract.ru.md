# Контракт Todoing для Manifest

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-23**  

# Description
Целевая спецификация интеграции Manifest с Todoing JSON API v1.

**Основа:** Todoing zhihus/todoing-x main @ 947048d3864e99c7d0dfcc48889a084e0a99e42d; Manifest feature/todoing-contract-spec.

> Эта редакция заменяет прежнюю целевую модель CLI + файловый WAL. Она описывает целевое потребление Todoing JSON API v1 и включает требования к универсальным расширениям Todoing, необходимым для сохранения ранее утверждённых решений Manifest. Исторические редакции v2–v6 сохранены отдельными файлами в Git.

## 1. Архитектурный принцип и границы ответственности

Todoing — самостоятельный универсальный инструмент управления задачами. Manifest — один из его потребителей. Todoing не зависит от Manifest и не содержит знаний о Manifest, OpenSpec, ролях агентов или политике проекта.

### 1.1. Todoing предоставляет

- отдельное SQLite-хранилище задач на проект;
- настраиваемые статусы и разрешённые переходы;
- создание, чтение, изменение, завершение, отмену, архивирование и восстановление задач;
- зависимости задач с защитой от циклов;
- универсальные внешние ссылки на связанные артефакты;
- неизменяемые версии, append-only историю операций и структурированную историю Review;
- baseline утверждённой версии;
- эксклюзивные блокировки с lease, heartbeat, recovery и fencing generation;
- ссылки на Git-коммиты в виде полных SHA с различением обычного и итогового commit reference;
- CLI и версионируемый JSON API v1;
- проверку, миграцию и создание проверенных снимков хранилища.

### 1.2. Manifest отвечает за

- стабильный Project ID, выбор и инициализацию хранилища проекта;
- оркестрацию, роли, последовательность и назначение агентов;
- пользовательские согласования и правила завершения проекта;
- workflow OpenSpec и интерпретацию универсальных внешних ссылок как OpenSpec change;
- политику Git: ветки, review и merge;
- цикл Review и полномочия Reviewer;
- согласованность Todoing ↔ OpenSpec ↔ Git;
- аутентификацию акторов и безопасное хранение lock token;
- резервирование, место хранения и срок хранения snapshot.

Todoing не парсит OpenSpec и не проверяет Git workflow: он хранит только универсальные ссылки и commit references. Он не аутентифицирует actor и не обеспечивает ролевую политику потребителя.

## 2. Версия и транспорт API

### 2.1. Нормативный интерфейс

Manifest использует только публичный JSON API v1 через CLI-команду todoing api. Каждый вызов — отдельный процесс: один JSON request через stdin, один JSON response через stdout. Диагностика направляется в stderr.

Обязательные поля request envelope: api_version=1, project_id, actor_id, operation, args. Дополнительно могут передаваться request_id и lock_token. Неизвестные поля, неподдерживаемые операции и версии API отклоняются. Ошибка возвращается в JSON envelope и сопровождается ненулевым exit code.

### 2.2. Идентичность и безопасность

- Manifest назначает стабильный Project ID и передаёт его в каждом запросе.
- Todoing сверяет Project ID с метаданными хранилища. Это защита от обращения не к тому хранилищу, а не аутентификация.
- actor_id — атрибуция в истории, а не доказательство личности. Manifest формирует actor ID по собственной модели доверия.
- Lock token — секрет: его нельзя помещать в task body, labels, логи, аргументы командной строки или Git. Manifest хранит его только в защищённом состоянии сессии агента и передаёт в envelope как lock_token.
- Manifest не читает и не изменяет SQLite напрямую.

### 2.3. Совместимость

Manifest опирается на API v1 и его нормативные схемы/операции. Нельзя определять поддержку операции пробным изменяющим вызовом. Перед использованием интеграция проверяет доступность бинарного файла и совместимость API; runtime capabilities discovery в Todoing отсутствует и для MVP не требуется.


### 2.4. Обязательные универсальные расширения API v1

Текущая реализация Todoing API v1 не предоставляет все ранее утверждённые
возможности. До интеграции Manifest Todoing должен расширить API и SQLite schema
следующими универсальными механизмами. Расширения не должны содержать
Manifest-specific или OpenSpec-specific поля и правила.

**External references**

- `task.external-ref.add`: принимает `task_id`, `namespace`, `value` и
  `relation`; создаёт типизированную ссылку на внешний артефакт.
- `task.external-ref.list`: возвращает ссылки задачи.
- `task.external-ref.remove`: удаляет активную связь append-only событием,
  сохраняя историю и версии.
- Уникальность активной связи в пределах `namespace + value` обеспечивает
  эксклюзивность связи в одном project store; Todoing не интерпретирует namespace.
- Внешние ссылки входят в snapshots и immutable task versions.

**Review records**

- `task.review.add`: принимает `task_id`, `review_id`, `version_no`,
  `outcome` (`approved` или `changes_requested`) и массив `comments`.
  Reviewer атрибутируется через envelope `actor_id`.
- `task.review.list`: возвращает append-only историю Review с пагинацией.
- Повторный `review_id` с тем же payload идемпотентен; тот же ID с иным
  payload отклоняется.
- Review привязан к существующей immutable version. Добавление записи не
  меняет workflow status.
- Каждая новая Review record и соответствующая task version/history event
  сохраняются атомарно. Идемпотентный повтор не создаёт новую версию.
- `revision_count` — вычисляемое количество Review records с outcome
  `changes_requested`; отдельный дублирующий счётчик не хранится.

**Final commit reference**

- `task.commit.finalize` принимает `task_id` и Git revision, разрешает его
  в полный SHA и назначает единственную итоговую commit reference.
- Операция требует активную блокировку владельца; изменение отражается в
  immutable version и append-only history.
- Обычные commit references остаются отдельными traceability references.

## 3. Модель задачи и статусов

### 3.1. Источник истины

Todoing — единственный источник текущих workflow status и outcome задачи. Manifest не хранит их вторую копию и не поддерживает таблицу синхронизации двух наборов статусов. Manifest отдельно хранит собственные этапы оркестрации и review metadata; они не подменяют статус Todoing.

### 3.2. Рекомендуемая конфигурация Manifest

Manifest поставляет рекомендуемый .todoing/config.toml, но не изменяет конфигурацию без явного действия при инициализации или отдельного согласованного процесса.

| ID | Отображаемое имя | Назначение |
|---|---|---|
| backlog | Backlog | Обсуждение и детализация задачи |
| ready | К выполнению | Пользователь утвердил задачу |
| in_progress | Выполняется | Агент выполняет задачу |
| review | На проверке | Результат передан Reviewer |
| verified | Проверено | Reviewer подтвердил результат |
| completed | Завершено | Оркестратор выполнил итоговую проверку |

Предлагаемый граф переходов: backlog → ready → in_progress → review; из review — в verified при одобрении Reviewer или обратно в in_progress при замечаниях; из verified — в completed после итоговой проверки. Другие переходы запрещены, кроме явно предусмотренной операции reopen для терминального outcome. Граф конфигурируется в Todoing и проверяется интеграционными тестами.

В API v1 нет операции изменения config.toml. Рекомендуемая конфигурация является файлом проекта; Manifest должен управлять её установкой отдельной контролируемой операцией, не изменяя SQLite напрямую. Способ установки и защита пользовательских изменений уточняются в спецификации и реализации Manifest.

Связь status ID с outcome задаётся явно в конфигурации Todoing: Todoing не выводит её из имени или отображаемой метки статуса. Для Manifest предлагается связать completed с outcome completed. Терминальный outcome требует явного reopen перед дальнейшим изменением. Отмена выполняется отдельной операцией task.cancel и не требует отдельного workflow status.

### 3.3. Status, outcome и archive — разные измерения

- Workflow status описывает этап работы.
- Outcome описывает завершение или отмену: active, completed, cancelled.
- Archive state скрывает задачу из активного списка, не меняя status или outcome.

Manifest не трактует archive как отмену и не использует физическое удаление. Отмена по согласованию пользователя фиксируется операцией task.cancel с причиной; Todoing сохраняет текущий workflow status и устанавливает outcome cancelled. Связанный OpenSpec change архивируется Manifest штатным механизмом OpenSpec Archive. Основные спецификации OpenSpec не обновляются.

## 4. Операционные сценарии

### 4.1. Инициализация проекта

1. Manifest определяет и сохраняет стабильный Project ID.
2. Manifest вызывает store.init с этим ID.
3. Manifest проверяет результат через store.info и store.verify.
4. Manifest применяет рекомендуемую конфигурацию статусов только в рамках явно предусмотренной и подтверждённой операции настройки.
5. При существующих legacy Markdown-данных Manifest не вызывает store.init поверх них; миграция выполняется отдельно через store.migrate после проверки отчёта миграции.

### 4.2. Создание и утверждение задачи

- Analyst предлагает задачу в Backlog в совместной работе с пользователем.
- Manifest проверяет дубли и зависимости; Todoing создаёт задачу через task.create со статусом backlog.
- Пользователь утверждает содержание и переводит задачу в ready. Агент не может самостоятельно считать задачу утверждённой.
- После явного пользовательского утверждения Manifest при необходимости фиксирует baseline через task.version.approve для конкретной существующей версии. Todoing не аутентифицирует пользователя; Manifest вызывает approve только после подтверждённого пользовательского действия.

### 4.3. Выполнение задачи и блокировка

1. Оркестратор выбирает утверждённую задачу.
2. Агент получает блокировку через task.lock.acquire.
3. Manifest сохраняет owner ID, token и fencing generation в защищённом контексте сессии и передаёт token в каждом owner-запросе.
4. Пока работа продолжается, агент продлевает lease через task.lock.heartbeat.
5. Manifest переводит задачу в in_progress и выполняет разрешённые операции.
6. По окончании агент освобождает блокировку через task.lock.release.

Заблокированная задача недоступна другим клиентам для чтения и изменения. Списки Todoing не раскрывают даже ID заблокированных задач. Manifest не обходит это ограничение чтением БД или snapshot.

### 4.4. Передача на Review и возврат

- Перед передачей результата Manifest переводит задачу в review и передаёт Reviewer необходимые артефакты через собственный workflow.
- Reviewer независимо проверяет результат.
- При одобрении Todoing сохраняет структурированную запись Review с outcome approved; Manifest переводит задачу в verified.
- При запросе изменений Todoing атомарно сохраняет запись Review с outcome changes_requested и увеличивает revision_count ровно на один; Manifest возвращает задачу в in_progress.
- Повторная отправка того же review_id с идентичным содержимым идемпотентна; тот же ID с другим содержимым отклоняется. Review record ссылается на конкретную immutable version задачи. Запись Review не меняет workflow status. Повторные циклы не создают отдельные Todoing статусы.

revision_count — количество Review records с outcome changes_requested, а не количество версий или комментариев. Todoing хранит Review history и revision_count как универсальные данные задачи; Manifest определяет, когда Reviewer вправе создать такую запись и какие действия следуют из её outcome.

### 4.5. Итоговое завершение

После статуса verified оркестратор выполняет итоговые проверки согласованности Todoing, OpenSpec и Git. При успехе переводит задачу в completed (и тем самым фиксирует outcome completed, если статус настроен соответствующим образом). Наличие Git commit reference само по себе не означает завершение.

### 4.6. Отмена

1. Любой агент может рекомендовать отмену с обоснованием.
2. Отмену подтверждает только пользователь.
3. После подтверждения Manifest вызывает task.cancel с причиной.
4. Manifest архивирует связанный OpenSpec change штатным механизмом Archive.
5. Основные спецификации OpenSpec не изменяются.

Отмена не должна выполняться только переводом статуса или архивированием задачи. Outcome и OpenSpec archive фиксируются отдельными действиями. Повторное открытие отменённой задачи требует явного решения и операции task.reopen.

## 5. Версии, история и Git

- Каждое успешное сохранение состояния задачи в Todoing создаёт неизменяемую версию и запись истории в одной транзакции; no-op не создаёт новую версию.
- Manifest использует task.history.list, task.version.list, task.version.get и task.version.compare для аудита и сопоставления.
- task.version.approve задаёт baseline существующей версии и не создаёт новую.
- Git-связь добавляется через task.commit.add; Todoing разрешает revision в полный SHA. Итоговая ссылка назначается отдельно через task.commit.finalize. Обе ссылки — метаданные прослеживаемости, не доказательство выполнения критериев.
- Политика веток, review, merge и определение итогового коммита принадлежат Manifest.
- OpenSpec change ID и другие внешние идентификаторы не помещаются в Git commit references. Manifest связывает их с Task ID через универсальный API external references Todoing.

## 6. Зависимости

Manifest управляет зависимостями через task.dependency.add, task.dependency.remove и task.dependency.list. Связи с внешними артефактами и Review records хранятся в Todoing через универсальные API-операции, определённые в §2.4; они отсутствуют в текущей реализации и должны быть реализованы в Todoing без Manifest-specific semantics.

- Зависимость означает, что задача не должна начинаться до выполнения prerequisite согласно политике Manifest.
- Todoing проверяет существование задач и запрещает циклы, но не решает, когда зависимость считается выполненной для workflow Manifest.
- Manifest проверяет outcome/status зависимостей перед запуском задачи.
- Сведения о заблокированной задаче могут быть скрыты Todoing; Manifest не пытается получить их обходным путём.

## 7. Ошибки и восстановление

Manifest обрабатывает стабильные коды ошибок API v1 по их машинным значениям, а не по тексту message.

| Ситуация | Поведение Manifest |
|---|---|
| project_id_mismatch | Остановить интеграцию проекта; не переинициализировать store автоматически |
| task_not_found | Зафиксировать нарушение целостности ссылки и запросить разбор |
| task_locked | Не читать/не изменять задачу; передать управление владельцу или ждать |
| lock_expired / stale_lock | Прекратить owner-операции; пройти явный recovery workflow |
| invalid_status_transition | Не обходить граф; проверить конфигурацию и состояние задачи |
| task_terminal | Требуется явное решение о reopen; не повторять мутацию автоматически |
| task_archived | Не выполнять мутации до явного restore |
| dependency_cycle | Отклонить изменение зависимостей и сообщить о цикле |
| store_corrupt / history_record_failed | Fail closed: остановить мутации и эскалировать пользователю |
| store_busy | Повтор допустим только при retryable=true и с ограниченной политикой повторов |
| invalid_request / unsupported_api_version | Считать ошибкой интеграции; не повторять без изменения запроса/совместимости |

При истечении lease Todoing не передаёт владение автоматически. Manifest может вызвать task.lock.recover только после условий recovery, предусмотренных Todoing. Recovery создаёт новый token и увеличивает fencing generation; старый владелец становится недействительным. После recovery Manifest проверяет актуальную версию задачи до продолжения работы.

## 8. Hooks, events и cross-component consistency

Manifest не зависит от Todoing hooks/events. SQLite backend Todoing не запускает legacy Markdown hooks, а generic lifecycle event API отложен и не имеет обещанной delivery/retry/order semantics.

Все проверки, влияющие на корректность Manifest, выполняются самим Manifest:
- до операции — проверка предусловий и полномочий;
- после операции — проверка результата Todoing и согласованности с OpenSpec/Git;
- при сбое между компонентами — обнаружение частичного результата и явное восстановление по журналируемому workflow Manifest.

Операции Todoing и изменения OpenSpec/Git не образуют общей транзакции. Manifest обязан проектировать их как последовательность проверяемых шагов с идемпотентными повторами или явным восстановлением; нельзя обещать атомарность между системами.

## 9. Snapshot, backup и migration

- Manifest вызывает store.snapshot, а не копирует активный SQLite-файл.
- Snapshot запрещён Todoing при наличии активных task locks. Manifest планирует его вне рабочих сессий.
- Manifest владеет destination, retention и replication policy.
- store.verify используется для проверки целостности.
- store.migrate применяется только как отдельная non-destructive процедура с предварительным dry run и проверкой отчёта.
- Git не считается резервной копией Todoing store.

## 10. Состав MVP

### Входит

1. Инициализация одного Todoing store на проект с постоянным Project ID.
2. JSON API v1 transport и проверка совместимости.
3. Рекомендуемая конфигурация шести workflow статусов.
4. Создание задач, переходы статусов, outcome complete/cancel.
5. Task locks, heartbeat, release и явный recovery.
6. Dependencies.
7. История, версии, version compare и user-approved baseline.
8. Git commit references.
9. Todoing-side generic external references, Review history и revision_count; Manifest-side workflow policy.
10. Manifest-side проверки согласованности и восстановление частичных операций.
11. Проверка store и создание snapshot по запросу.

### Не входит

- Manifest-specific поля и операции в Todoing; универсальные расширения external references, Review records и final commit marker входят в интеграционное предусловие MVP.
- Todoing capabilities discovery API.
- Todoing lifecycle events/hooks как условие корректности.
- Произвольные внешние ссылки без типизированного generic reference contract.
- GUI Todoing, multi-project dashboard.
- Реализация удалённого backup, репликации и политики хранения snapshot.
- Автоматическая синхронизация конфигурации статусов без явного действия.
- Автоматическая миграция legacy-хранилища без предварительного dry run и согласования.

## 11. Матрица соответствия требований

| Требование Manifest | Механизм | Владелец | Статус |
|---|---|---|---|
| Задачи и статусы | task.create, task.status.set, config.toml | Todoing; политика — Manifest | Поддерживается |
| Outcome завершения/отмены | task.complete, task.cancel, task.reopen | Todoing; согласование — Manifest | Поддерживается |
| История и версии | task.history.list, task.version.* | Todoing | Поддерживается |
| Baseline утверждения | task.version.approve | Todoing; разрешение — Manifest/user | Поддерживается |
| Блокировки и fencing | task.lock.* | Todoing; token custody — Manifest | Поддерживается |
| Зависимости | task.dependency.* | Todoing; gate выполнения — Manifest | Поддерживается |
| Git SHA и итоговый commit | task.commit.add, task.commit.finalize | Todoing | Частично; final marker требует расширения |
| OpenSpec Task link | Generic external references | Todoing API extension; semantics — Manifest | Требует универсального расширения Todoing |
| Reviewer remarks/history | Generic review records | Todoing API extension; policy — Manifest | Требует универсального расширения Todoing |
| revision_count | Count of changes_requested review records | Todoing API extension | Требует универсального расширения Todoing |
| Cross-system consistency | Consumer checks/workflow | Manifest | Требует реализации Manifest |
| Capabilities discovery | Не используется в MVP | — | Отложено |
| Generic hooks/events | Не используются для корректности | — | Отложено |

## 12. Приёмочные сценарии интеграции

1. Store инициализируется с ожидаемым Project ID; запрос с другим ID отклоняется.
2. Analyst создаёт задачу в Backlog; пользовательское утверждение переводит её в Ready.
3. Неутверждённая задача не может быть запущена оркестратором.
4. Агент получает lock; другой actor не может прочитать или изменить задачу.
5. Heartbeat продлевает lease; истёкший lock нельзя продлить.
6. Recovery создаёт новую fencing generation; прежний владелец не может продолжить работу.
7. Недопустимый status transition отклоняется Todoing и не обходится Manifest.
8. Reviewer changes_requested создаёт запись review history Manifest и увеличивает revision_count ровно на один; число версий Todoing не используется как счётчик.
9. Reviewer approved переводит задачу в Verified; итоговая проверка переводит в Completed.
10. Отмена возможна только после пользовательского подтверждения; фиксируется outcome cancelled и архивируется связанный OpenSpec change, основные спецификации не меняются.
11. Git SHA связывается с задачей, но не считается доказательством завершения.
12. Сбой между Todoing и OpenSpec/Git обнаруживается и обрабатывается recovery workflow; ложная атомарность между системами не предполагается.
13. Snapshot не создаётся при активной блокировке; после освобождения блокировок проходит verify.
14. Все критические ошибки обрабатываются по error code; повреждение store/history приводит к остановке мутаций.

## 13. Вопросы, требующие решения до утверждения

1. **Конфигурация статусов:** подтвердить предложенные IDs/labels и граф переходов; отдельно определить механизм безопасной установки и обновления config.toml, поскольку API v1 не предоставляет операции изменения конфигурации.
2. **Outcome mapping:** подтвердить, что completed status отображается в outcome completed; определить пользовательское отображение отменённой задачи, поскольку отмена — outcome, а не отдельный workflow status.
3. **Универсальные API-расширения Todoing:** утвердить схему external references, Review records, final commit marker, идемпотентность review_id и миграцию SQLite schema; расширение не должно содержать терминов или правил Manifest/OpenSpec.
4. **Утверждение baseline:** определить, на каком пользовательском gate Manifest вызывает task.version.approve и какие версии требуют baseline.
5. **Project ID и actor ID:** закрепить формат и источник стабильных идентификаторов в Manifest.

До разрешения этих вопросов документ остаётся проектом решения. Реализация интеграции Manifest не начинается; отдельно может выполняться универсальное расширение Todoing по утверждённым требованиям, если оно не вводит Manifest-specific semantics.

## 14. Источники и ограничения

Нормативные источники Todoing:
- docs/api/v1/operations.md;
- docs/api/v1/request.schema.json;
- docs/api/v1/response.schema.json;
- docs/integrations/consumer-contract.md;
- OpenSpec task-cli и связанные storage/API specifications.

Источники требований Manifest:
- architecture-brief.ru.md §7–9;
- architecture-decisions.ru.md §4–5;
- architecture-roadmap.ru.md §1–3;
- todoing-implementation-audit.ru.md.

Спецификация подготовлена по опубликованным документам Todoing на HEAD 947048d. Полный набор тестов Todoing в рамках аудита не запускался. Перед утверждением независимый Reviewer должен сверить каждый нормативный тезис с API schema, implementation и тестами. Если Todoing изменит API v1, спецификацию требуется пересмотреть до изменения интеграционного кода.
