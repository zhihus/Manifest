# Spec Delta

## Purpose

Определяет отображение OpenSpec change на Todoing task: создание задачи,
статусы, external reference и зависимости. Один OpenSpec change соответствует
ровно одному Todoing task; FR tasks внутри change — декомпозиция, а не
отдельные задачи Todoing.

## ADDED Requirements

### Requirement: Создание задачи и external reference

Система SHALL создавать Todoing task со статусом `backlog` и фиксировать
external reference: namespace `openspec.change`, value — ID каталога change,
relation `implements`, scope `project`. Задачу создаёт пользователь или
Аналитик предлагает её в Backlog.

#### Scenario: Создание задачи
- WHEN пользователь создаёт задачу или Аналитик предлагает её
- THEN система создаёт Todoing task со статусом `backlog` и фиксирует
  external reference namespace `openspec.change`

#### Scenario: Один change — одна задача
- WHEN создаётся задача для OpenSpec change
- THEN задача соответствует ровно одному change, и FR tasks внутри change не
  создаются отдельными задачами Todoing

### Requirement: Утверждение перехода backlog → ready

Переход `backlog → ready` SHALL утверждать только пользователь. Агент не
считает задачу утверждённой самостоятельно. После утверждения Manifest при
необходимости фиксирует baseline через `task.version.approve`.

#### Scenario: Утверждение пользователем
- WHEN пользователь утверждает задачу
- THEN система переводит задачу в `ready`

#### Scenario: Без утверждения пользователя
- WHEN пользователь не утвердил задачу
- THEN система не переводит её в `ready` и не начинает выполнение

### Requirement: Выполнение и статусы

Система SHALL переводить утверждённую задачу в `in_progress` при начале
выполнения. Статусы: `backlog → ready → in_progress → review → verified →
completed`; из `review` — в `verified` при одобрении или обратно в
`in_progress` при замечаниях.

#### Scenario: Начало выполнения
- WHEN Orchestrator приобретает lock для утверждённой задачи
- THEN система переводит задачу в `in_progress`

#### Scenario: Цикл статусов
- WHEN выполняется пайплайн
- THEN статусы переходят `in_progress → review → verified → completed`
  (или `review → in_progress` при замечаниях)

### Requirement: Уникальность external reference

Система SHALL обеспечивать не более одной активной ссылки namespace
`openspec.change` на задачу и не более одной задачи на change ID. При отмене
ссылка сохраняется для аудита.

#### Scenario: Одна ссылка на задачу
- WHEN задаче добавляется внешняя ссылка namespace `openspec.change`
- THEN на задачу действует не более одной активной ссылки этого namespace

#### Scenario: Один change ID — одна задача
- WHEN change ID уже привязан к задаче
- THEN он не привязывается ко второй задаче

#### Scenario: Сохранение ссылки при отмене
- WHEN задача отменена
- THEN external reference сохраняется для аудита