# Spec Delta

## Purpose

Определяет цикл Review: передачу задачи на проверку, запись Review с
outcome, обработку одобрения и замечаний (revision_count), идемпотентность
записи Review.

## ADDED Requirements

### Requirement: Передача на проверку

Перед передачей результата Orchestrator SHALL переводить задачу в `review` и
передавать Reviewer артефакты через собственный workflow.

#### Scenario: Передача
- WHEN Orchestrator готов передать результат
- THEN он переводит задачу в `review` и передаёт Reviewer артефакты

### Requirement: Запись Review

Система SHALL вызывать `task.review.add` с `review_id`, `version_no`
проверяемой версии, `reviewer` label, `outcome` (`approved`/
`changes_requested`) и упорядоченным массивом `comments`. `actor_id` envelope
фиксирует агента Reviewer.

#### Scenario: Запись одобрения
- WHEN Reviewer одобряет версию
- THEN система вызывает `task.review.add` с outcome `approved` и
  упорядоченным массивом `comments`

#### Scenario: Запись замечаний
- WHEN Reviewer возвращает замечания
- THEN система вызывает `task.review.add` с outcome `changes_requested`

### Requirement: Обработка одобрения

При outcome `approved` Todoing SHALL сохранить запись Review, а Manifest SHALL
перевести задачу в `verified`.

#### Scenario: Одобрение
- WHEN запись Review с outcome `approved` сохранена
- THEN Manifest переводит задачу в `verified`

### Requirement: Обработка замечаний

При outcome `changes_requested` Todoing SHALL атомарно сохранить запись и
увеличить `revision_count` ровно на один; Manifest SHALL вернуть задачу в
`in_progress`.

#### Scenario: Замечания
- WHEN запись Review с outcome `changes_requested` сохранена
- THEN `revision_count` увеличивается ровно на один и задача возвращается в
  `in_progress`

### Requirement: Идемпотентность записи Review

Повторный `review_id` с идентичным payload SHALL быть no-op; тот же ID с
иным payload SHALL возвращать `review_id_conflict`. Review не меняет workflow
status.

#### Scenario: Повторный review_id
- WHEN `task.review.add` вызывается повторно с тем же `review_id` и
  идентичным payload
- THEN операция является no-op

#### Scenario: Конфликт review_id
- WHEN `task.review.add` вызывается с тем же `review_id`, но иным payload
- THEN возвращается `review_id_conflict`