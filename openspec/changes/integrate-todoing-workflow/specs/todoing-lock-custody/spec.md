# Spec Delta

## Purpose

Определяет модель блокировок (lock custody) для интеграции: Orchestrator —
единственный владелец lock token; модель учитывает блокирующее выполнение
ролевого субагента, при котором Orchestrator не может отправлять heartbeat.

## ADDED Requirements

### Requirement: Приобретение lock

Оркестратор SHALL вызывать `task.lock.acquire` для утверждённой задачи,
получать `owner_id`, `lock_token`, `fencing_generation`, `expires_at` и
хранить token только в защищённом состоянии сессии. Token передаётся в
envelope каждого owner-запроса. Ролевые субагенты не получают lock token и не
вызывают Todoing.

#### Scenario: Приобретение
- WHEN Orchestrator начинает выполнение утверждённой задачи
- THEN он вызывает `task.lock.acquire` и получает lock token

#### Scenario: Субагенты не получают token
- WHEN Orchestrator запускает ролевого субагента
- THEN субагент не получает lock token и не вызывает Todoing напрямую

### Requirement: Heartbeat только при активности Orchestrator

Оркестратор SHALL продлевать lease через `task.lock.heartbeat` только когда
сам активен — между запусками субагентов и на гейтах. Во время блокирующего
выполнения субагента Orchestrator заблокирован и heartbeat не отправляет.

#### Scenario: Heartbeat на гейтах
- WHEN Orchestrator активен (между запусками субагентов, на гейтах)
- THEN он отправляет `task.lock.heartbeat` для продления lease

#### Scenario: Нет heartbeat во время субагента
- WHEN Orchestrator заблокирован во время выполнения субагента
- THEN heartbeat не отправляется

### Requirement: Lease покрывает hard timeout

Система SHALL настраивать lease на 720 с (hard timeout выполнения субагента
600 с + запас 120 с), чтобы lease пережил полный run субагента, если
Orchestrator heartbeat'ит непосредственно перед запуском.

#### Scenario: Lease переживает run субагента
- WHEN Orchestrator heartbeat'ит непосредственно перед запуском субагента
- THEN lease (720 с) переживает полный 600-секундный run субагента

### Requirement: Освобождение lock

Оркестратор SHALL освобождать lock через `task.lock.release` по завершении
задачи.

#### Scenario: Освобождение
- WHEN задача завершена
- THEN Orchestrator вызывает `task.lock.release`

### Requirement: Recovery после истечения lease

При истечении lease Todoing не передаёт владение автоматически. После
истечения lease и recovery grace (60 с) Orchestrator SHALL вызывать
`task.lock.recover`, получая новый token и увеличенный fencing generation.
Старый владелец становится недействительным. После recovery Orchestrator
проверяет актуальную версию задачи перед продолжением.

#### Scenario: Явный recovery
- WHEN lease истёк и прошло recovery grace (60 с)
- THEN Orchestrator вызывает `task.lock.recover` и получает новый token с
  увеличенным fencing generation

#### Scenario: Старый token недействителен
- WHEN выполнен recovery
- THEN старый token становится недействительным и не используется

#### Scenario: Проверка версии после recovery
- WHEN Orchestrator продолжает работу после recovery
- THEN он проверяет актуальную версию задачи перед продолжением