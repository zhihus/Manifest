# Design — Восстановление после частичного сбоя

## Принципы

- Todoing, OpenSpec и Git не образуют транзакции. Каждое изменение —
  проверяемый шаг с идемпотентным повтором или явным восстановлением.
- **SQLite restore не откатывает OpenSpec или Git.** Snapshot Todoing восстанавливает только Todoing store; после restore обязательна сверка всех трёх систем до повторных операций.\n- **Нет слепых повторов non-idempotent операций.** Перед повтором операции
  Orchestrator сверяет фактическое состояние соответствующей системы.
- Recovery начинается с чтения актуального состояния всех трёх систем
  (Todoing: статус, outcome, версии; OpenSpec: наличие/архивация change,
  permanent specs; Git: ветка, merge, SHA) и только затем — с решения, какие
  операции ещё не выполнены.
- **Состояние lock не читается публичной операцией.** Todoing не предоставляет
  read-only операции чтения lock-state. Orchestrator знает, что владеет lock,
  потому что сам приобрёл token; актуальность lock проверяется операцией,
  валидирующей grant (например, `task.lock.heartbeat`): успех — lock активен и
  удерживается этим токеном, `stale_lock` — token больше не действителен
  (lock мог быть освобождён либо перехвачен через recovery),
  `lock_expired` — lease истёк.

## Состояния и их согласование

| Шаг | Факт в Todoing | Факт в OpenSpec | Факт в Git |
|---|---|---|---|
| Задача утверждена | status `ready` | change существует | — |
| Выполнение | status `in_progress`, lock активен | — | ветка change |
| Review | status `review` | — | — |
| Одобрение | status `verified` | — | — |
| Archive | — | change в `archive/`, permanent specs обновлены | — |
| Merge | — | — | merge commit |
| Finalize | commit reference с SHA | — | SHA |
| Complete | status `completed`, outcome `completed` | — | — |

## Сценарии восстановления

### S1. Сбой между OpenSpec archive и Git merge

- Факт: change уже в `archive/`, permanent specs обновлены, merge не
  выполнен.
- Действие: не повторять archive (идемпотентно: change уже в архиве).
  Выполнить Git merge. После merge — `task.commit.finalize` с SHA, затем
  `task.status.set` → `completed`.
- Проверка: SHA merge commit существует; `task.commit.finalize` no-op при
  повторе с тем же SHA.

### S2. Сбой между Git merge и `task.commit.finalize`

- Факт: merge выполнен, commit reference не зафиксирован.
- Действие: получить SHA merge commit, выполнить `task.commit.finalize`.
  Повтор с тем же SHA — no-op. Затем `task.status.set` → `completed`.

### S3. Сбой между переходом в `completed` и освобождением lock

- Факт: статус `completed`, outcome `completed`, lock ещё активен либо
  освобождение не подтверждено (ответ на `task.lock.release` потерян).
- Публичной операции чтения lock-state нет; актуальность владения
  проверяется операцией, валидирующей grant — `task.lock.heartbeat`.
- Действие: Orchestrator отправляет `task.lock.heartbeat`:
  - успешный heartbeat подтверждает действующий token (lock активен и
    удерживается этим токеном) → выполнить `task.lock.release`;
  - `lock_expired` — lease истёк, token не продлевается. Истечение lease не
    запускает автоматический takeover: `task.lock.recover` выполняется только
    явным вызовом после recovery grace. Если recovery не выполняется, истёкшая
    запись lock остаётся до последующего явного recovery;
  - `stale_lock` — token больше не действителен: lock мог быть освобождён либо
    перехвачен через recovery. Старый владелец не выполняет дальнейших
    операций с этим token.
- Запрет: повторный `task.lock.release` не идемпотентен — он возвращает
  `stale_lock` (lock не удерживается этим токеном). Повтор выполняется только
  после успешного heartbeat, подтверждающего владение.

### S4. Сбой при блокировке (lease истёк во время выполнения субагента)

- Факт: lease истёк, Orchestrator прерван.
- Действие: после истечения lease и recovery grace (60 с) Orchestrator
  вызывает `task.lock.recover`, получая новый token и увеличенный fencing
  generation. Recover атомен: выполняется в Exclusive-транзакции с CAS по
  `fencing_generation`, поэтому конкурирующие recover сериализуются — только
  первый успешен, последующий получает `task_locked` (свежий expiry в
  будущем). Старый token после recover недействителен на любой операции
  (`stale_lock`). Перед продолжением Orchestrator проверяет актуальную версию
  задачи и состояние артефактов.
- Запрет: не продолжать работу со старым token после recovery.

### S5. Сбой при отмене

Последовательность отмены: `task.cancel` (outcome `cancelled`) → штатный
OpenSpec archive (delta specs не вливаются) → `task.lock.release`.

- Факт: одна из операций выполнена, другая нет (например, `task.cancel`
  выполнен, archive нет; или archive выполнен, lock не освобождён).
- Действие: сверить факты.
  - Если outcome `cancelled` установлен — не повторять `task.cancel`
    (повтор → `task_terminal`); выполнить OpenSpec archive (без вливания
    delta specs), затем `task.lock.release`.
  - Если archive выполнен, а outcome не установлен — выполнить `task.cancel`,
    затем `task.lock.release`.
  - Если outcome `cancelled` и archive выполнены, но lock не освобождён —
    проверить владение через `task.lock.heartbeat` (успех → `release`;
    `stale_lock` → token больше не действителен: lock мог быть освобождён
    либо перехвачен через recovery, старый владелец не выполняет дальнейших
    операций с этим token; `lock_expired` → явный recovery после grace при
    необходимости).
- Запрет: не вливать delta specs в permanent specs при отмене; не повторять
  `task.cancel` после установленного outcome.

## Идемпотентность операций

| Операция | Повтор |
|---|---|
| `task.status.set` на тот же статус (задача не терминальна) | no-op |
| `task.status.set` на любой статус после установленного outcome | `task_terminal` |
| `task.review.add` с тем же `review_id` и payload | no-op |
| `task.commit.finalize` с тем же SHA | no-op |
| `task.lock.release` при отсутствии активного lock этого token | `stale_lock` (не идемпотентный успех); повтор только после подтверждения владения heartbeat'ом |
| `task.complete` после установленного outcome | `task_terminal` |
| `task.cancel` после `cancelled` | `task_terminal` |

## Запреты

- Не повторять `store.init` поверх существующего store.
- Не выполнять `store.migrate` без dry-run и подтверждения пользователя.
- Не запускать реализацию интеграции до отдельного одобрения change.
- Не изменять Todoing, governance-документы Manifest и permanent specs
  в рамках этого change.