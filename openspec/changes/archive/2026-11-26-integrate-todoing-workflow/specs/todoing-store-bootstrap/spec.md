# Spec Delta

## Purpose

Определяет процедуру bootstrap Todoing хранилища для Manifest: проверку
доступности бинарного файла, запись конфигурации без перезаписи, вызов
`store.init` только для нового хранилища и отказ от перезаписи legacy данных
и существующего store.

## ADDED Requirements

### Requirement: Проверка доступности Todoing

Система SHALL проверять, что бинарный файл `todoing` доступен в PATH и что
`todoing api --json` отвечает. Установка Todoing выполняется пользователем;
Manifest не скачивает и не обновляет бинарный файл.

#### Scenario: Todoing доступен
- WHEN `todoing` в PATH и `todoing api --json` отвечает
- THEN bootstrap продолжается

#### Scenario: Todoing недоступен
- WHEN `todoing` недоступен или не отвечает
- THEN bootstrap останавливается с диагностикой; установка выполняется
  пользователем отдельно

### Requirement: Конфигурация без перезаписи

Система SHALL создавать `.todoing/` и записывать рекомендуемый
`config.toml` атомарно только когда файла ещё нет. Существующий
`config.toml` валидируется и сохраняется; при несовместимости bootstrap
останавливается.

#### Scenario: Конфигурация отсутствует
- WHEN `.todoing/config.toml` отсутствует
- THEN система атомарно записывает рекомендуемую конфигурацию

#### Scenario: Конфигурация существует
- WHEN `.todoing/config.toml` существует
- THEN система валидирует его (статусы, outcome mapping, переходы) и не
  перезаписывает

#### Scenario: Несовместимая конфигурация
- WHEN существующий `config.toml` несовместим
- THEN bootstrap останавливается с диагностикой; файл не перезаписывается

### Requirement: Инициализация store

Система SHALL вызывать `store.init` с Project ID из `.manifest/project-id`.
Операция создаёт новое хранилище только когда БД не существует.

#### Scenario: Новое хранилище
- WHEN `todoing.db` не существует
- THEN `store.init` создаёт новое хранилище

#### Scenario: Хранилище уже существует
- WHEN `todoing.db` существует
- THEN `store.init` возвращает `store_already_initialized`; система не
  переинициализирует store

#### Scenario: Legacy данные
- WHEN присутствуют legacy Markdown задачи (`.todoing/tasks/*.md`) или
  `index.json`
- THEN `store.init` возвращает `migration_required`; система не выполняет
  `store.init` и предлагает отдельную процедуру миграции

### Requirement: Проверка хранилища

Система SHALL проверять результат инициализации через `store.info` и
`store.verify`.

#### Scenario: Хранилище инициализировано
- WHEN `store.info` и `store.verify` подтверждают корректность
- THEN bootstrap завершается успешно

#### Scenario: Хранилище некорректно
- WHEN `store.info` или `store.verify` обнаруживает проблему
- THEN bootstrap останавливается с диагностикой