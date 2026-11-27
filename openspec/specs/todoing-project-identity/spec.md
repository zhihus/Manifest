# todoing-project-identity Specification

## Purpose
Определяет механизм Project Identity для интеграции Manifest с Todoing:
генерацию, валидацию и защиту стабильного Project ID, хранящегося в
`.manifest/project-id` и передаваемого в каждом запросе Todoing API.

## Requirements

### Requirement: Генерация Project ID

Система SHALL генерировать Project ID в формате UUIDv4 и атомарно записывать
его в `.manifest/project-id`, когда файл отсутствует и store не существует.

#### Scenario: Первичная генерация
- WHEN `.manifest/project-id` отсутствует и Todoing store не существует
- THEN система генерирует UUIDv4 и атомарно записывает его в
  `.manifest/project-id`

#### Scenario: Файл уже существует
- WHEN `.manifest/project-id` существует
- THEN система использует его значение и не генерирует новый ID

### Requirement: Валидация Project ID

Система SHALL валидировать Project ID по правилам Todoing (1–128 символов,
без whitespace в начале/конце, без контрольных символов) при каждом запуске
интеграции и, при существующем store, сверять его с `store.info`.

#### Scenario: Валидный ID
- WHEN Project ID проходит валидацию Todoing и совпадает с `store.info`
- THEN интеграция продолжается

#### Scenario: Несовпадение со store
- WHEN Project ID не совпадает с `store.info`
- THEN система останавливается с диагностикой `project_id_mismatch` и не
  переинициализирует store

### Requirement: Обработка отсутствия Project ID

Система SHALL генерировать новый ID при отсутствии `.manifest/project-id`
только когда store не существует; при существующем store и отсутствии файла
система SHALL остановиться.

#### Scenario: Файл отсутствует, store отсутствует
- WHEN `.manifest/project-id` отсутствует и store не существует
- THEN система генерирует новый UUIDv4

#### Scenario: Файл отсутствует, store существует
- WHEN `.manifest/project-id` отсутствует, но store существует
- THEN система останавливается: ID неизвестен, store не
  переинициализируется

### Requirement: Защита Project ID

Система SHALL считать `.manifest/project-id` неизменяемым после создания:
автоматическая перезапись запрещена. Смена возможна только явным решением
пользователя с пересозданием store.

#### Scenario: Отсутствие автоматической перезаписи
- WHEN выполняется bootstrap и `.manifest/project-id` существует
- THEN система не перезаписывает файл

#### Scenario: Обнаружение несанкционированной смены
- WHEN Project ID в `.manifest/project-id` больше не совпадает с
  `store.info`
- THEN система обнаруживает несовпадение и останавливается
