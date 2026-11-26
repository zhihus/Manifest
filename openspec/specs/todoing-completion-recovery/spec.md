# todoing-completion-recovery Specification

## Purpose
Определяет итоговое завершение задачи, отмену и восстановление после
частичного сбоя между Todoing, OpenSpec и Git. Системы не образуют
транзакцию; повтор операций идемпотентен или явный.

## Requirements

### Requirement: Успешное завершение

Успешное завершение SHALL выполняться в последовательности: статус `verified`
(Review approved) → acceptance checks → штатный OpenSpec archive → Git merge
по политике Manifest → `task.commit.finalize` с final merge SHA →
`task.status.set` → `completed` (терминальный переход) → освобождение lock.
Final Commit SHA — маркер трассируемости, а не доказательство приёмки.

#### Scenario: Последовательность завершения
- WHEN достигнут статус `verified`
- THEN система выполняет acceptance checks, OpenSpec archive, Git merge,
  `task.commit.finalize` с final merge SHA, `task.status.set` → `completed`
  и освобождение lock

#### Scenario: Терминальный переход устанавливает outcome
- WHEN система выполняет `task.status.set` → `completed`
- THEN переход сам устанавливает outcome `completed` (статус отображён на
  outcome в `config.toml`); отдельный вызов `task.complete` в success-пути не
  выполняется, повторный `task.complete` отклоняется как `task_terminal`

#### Scenario: Final Commit SHA — маркер
- WHEN зафиксирован final merge SHA через `task.commit.finalize`
- THEN SHA служит маркером трассируемости, а не доказательством приёмки

### Requirement: Отмена

Отмену SHALL подтверждать только пользователь. После подтверждения
Orchestrator устанавливает outcome `cancelled` через `task.cancel`
(терминальный outcome; повтор → `task_terminal`), архивирует OpenSpec change
штатным механизмом Archive (delta specs не вливаются в permanent specs) и
освобождает lock через `task.lock.release`. External reference сохраняется
для аудита.

#### Scenario: Подтверждённая отмена
- WHEN пользователь подтверждает отмену
- THEN Orchestrator вызывает `task.cancel` (outcome `cancelled`), архивирует
  OpenSpec change (без вливания delta specs) и освобождает lock через
  `task.lock.release`

#### Scenario: Освобождение lock после отмены
- WHEN outcome `cancelled` установлен и change архивирован
- THEN Orchestrator освобождает lock через `task.lock.release` (допустимо
  после терминального outcome)

#### Scenario: Без подтверждения пользователя
- WHEN пользователь не подтвердил отмену
- THEN система не устанавливает outcome `cancelled` и не архивирует change

#### Scenario: Сохранение ссылки при отмене
- WHEN задача отменена
- THEN external reference сохраняется для аудита

### Requirement: Восстановление после частичного сбоя

Система SHALL восстанавливать состояние после частичного сбоя, сверяя
фактические состояния Todoing, OpenSpec и Git до повторения операций. Слепые
повторы non-idempotent операций запрещены.

#### Scenario: Сверка перед повтором
- WHEN операция не завершена из-за сбоя
- THEN система сверяет фактические состояния Todoing, OpenSpec и Git и
  определяет, какие операции ещё не выполнены

#### Scenario: Идемпотентный повтор
- WHEN операция идемпотентна (например, `task.commit.finalize` с тем же SHA)
- THEN система повторяет её безопасно

#### Scenario: Запрет слепого повтора
- WHEN операция non-idempotent
- THEN система не повторяет её без явного восстановления и сверки состояния

### Requirement: Сценарии восстановления

Система SHALL обеспечивать восстановление для сценариев частичного сбоя,
определённых в `design/recovery.md` (S1–S5): между OpenSpec archive и Git
merge, между Git merge и `task.commit.finalize`, между переходом в `completed`
и освобождением lock, при истечении lease во время субагента, при отмене.

#### Scenario: Сбой между archive и merge
- WHEN change уже в архиве, а Git merge не выполнен
- THEN система выполняет Git merge, затем `task.commit.finalize` с SHA и
  `task.status.set` → `completed`, не повторяя archive

#### Scenario: Сбой при блокировке
- WHEN lease истёк во время выполнения субагента
- THEN после lease и recovery grace Orchestrator выполняет `task.lock.recover`
  и проверяет актуальную версию задачи
