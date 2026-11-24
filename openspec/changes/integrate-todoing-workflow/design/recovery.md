# Design — Восстановление после частичного сбоя

## Принципы

- Todoing, OpenSpec и Git не образуют транзакции. Каждое изменение —
  проверяемый шаг с идемпотентным повтором или явным восстановлением.
- **Нет слепых повторов non-idempotent операций.** Перед повтором операции
  Orchestrator сверяет фактическое состояние соответствующей системы.
- Recovery начинается с чтения актуального состояния всех трёх систем
  (Todoing: статус, outcome, версии; OpenSpec: наличие/архивация change,
  permanent specs; Git: ветка, merge, SHA) и только затем — с решения, какие
  операции ещё не выполнены.
- **Состояние lock не читается публичной операцией.** Todoing не предоставляет
  read-only операции чтения lock-state. Orchestrator знает, что владеет lock,
  потому что сам приобрёл token; актуальность lock проверяется операцией,
  валидирующей grant (например, `task.lock.heartbeat`): успех — lock активен и
  удерживается этим токеном, `stale_lock`/`lock_expired` — lock потерян или
  просрочен.

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

- Факт: статус `completed`, outcome `completed`, lock ещё активен.
- Действие: выполнить `task.lock.release`. Повтор `task.lock.release` →
  `stale_lock` (lock не удерживается этим токеном). Это допустимое конечное
  состояние: lock уже освобождён или перезахвачен; слепой повтор не
  выполняется. Публичного способа отличить «я уже отпустил» от «меня
  перезахватили» нет — клиент опирается на идемпотентную семантику store.

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

- Факт: `task.cancel` выполнен, OpenSpec archive не выполнен (или наоборот).
- Действие: сверить оба факта. Если outcome `cancelled` — выполнить OpenSpec
  archive (без вливания delta specs). Если archive выполнен, а outcome не
  установлен — выполнить `task.cancel`.
- Запрет: не вливать delta specs в permanent specs при отмене.

## Идемпотентность операций

| Операция | Повтор |
|---|---|
| `task.status.set` на тот же статус (задача не терминальна) | no-op |
| `task.status.set` на любой статус после установленного outcome | `task_terminal` |
| `task.review.add` с тем же `review_id` и payload | no-op |
| `task.commit.finalize` с тем же SHA | no-op |
| `task.lock.release` без активного lock (не удерживается этим токеном) | `stale_lock` — допустимое конечное состояние, слепой повтор не выполняется |
| `task.complete` после установленного outcome | `task_terminal` |
| `task.cancel` после `cancelled` | `task_terminal` |

## Запреты

- Не повторять `store.init` поверх существующего store.
- Не выполнять `store.migrate` без dry-run и подтверждения пользователя.
- Не запускать реализацию интеграции до отдельного одобрения change.
- Не изменять Todoing, governance-документы Manifest и permanent specs
  в рамках этого change.