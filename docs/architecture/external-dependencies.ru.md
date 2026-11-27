# Реестр внешних зависимостей

# Метаданные
> **Status: approved**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-27**  

# Описание
Единственный источник перечня внешних бинарных инструментов,
которые могут вызывать скрипты инфраструктуры репозитория Manifest
(`scripts/*.sh` и hooks в `scripts/hooks/`). Добавление новой внешней зависимости требует записи
в этом реестре. Формат записи: инструмент, назначение, область
применения, способ обнаружения. Русская редакция авторитетна;
`external-dependencies.en.md` — перевод.

| Инструмент | Назначение | Область применения | Обнаружение |
| --- | --- | --- | --- |
| `bash` | интерпретатор всех скриптов инфраструктуры | `scripts/*.sh` и `scripts/hooks/*` | `#!/usr/bin/env bash` |
| `git` | работа с репозиторием, определение изменённых файлов | все инфраструктурные скрипты и hook `scripts/hooks/pre-commit` | preflight `command -v git` |
| SHA-256 (`sha256sum` или `shasum -a 256`) | защита конфигурации от перезаписи; байтовые проверки | manifest-init.sh (checksum guard), test-manifest-init.sh (checksum regression fixture) | детекция при запуске: `sha256sum`, иначе `shasum -a 256`; выбранная утилита используется согласованно |
| `perl` | рендеринг шаблонов manifest-init (подстановка placeholder'ов и условных блоков) | manifest-init.sh, функция `render_template` | preflight: `command -v perl` и `perl -e 'exit 0'` |
| `mktemp` | уникальные временные файлы и каталоги (защита от коллизий) | manifest-init.sh, verify.sh, test-manifest-init.sh, test-portability.sh | входит в coreutils / Git for Windows / macOS |
| `awk` | разбор вывода checksum, генерация fixture в verify.sh | manifest-init.sh, verify.sh | входит в базовый состав систем; BSD/GNU совместимость по используемым конструкциям |
| `cmp` | байтовое сравнение установленных файлов с рендером | manifest-init.sh, test-manifest-init.sh | coreutils / Git for Windows / macOS |
| `date` | дата создания конфигурации `created=` | manifest-init.sh (`date +%F`, локаленезависимо) | базовый состав систем |
| `grep`, `sed` | проверка остаточных placeholder'ов, фильтрация вывода | все инфраструктурные скрипты и тесты | используются только в переносимых конструкциях (без GNU-only флагов) |
| `find` | анализ типа проекта (кодовые файлы, docs/) | manifest-init.sh (`analyze_project`), verify.sh, test-portability.sh | POSIX-флаги без GNU-only расширений |
| `basename`, `dirname` | извлечение имени проекта и каталога скрипта | manifest-init.sh, test-manifest-init.sh | переносимые системные утилиты |
| `head`, `wc` | подсчёт и ограничение строк/слов в проверках и тестах | structure-parser.sh, test-manifest-init.sh | переносимые системные утилиты |
| `sort`, `tr` | сортировка нарушений и обработка токенов/вывода | structure-parser.sh, verify.sh, test-portability.sh | переносимые системные утилиты |
| `cat` | чтение контрольных файлов в тестах | test-manifest-init.sh | переносимая системная утилита |
| `chmod` | установка исполняемого бита тестового Perl-stub | test-manifest-init.sh | переносимая системная утилита |
| `env` | поиск Bash по PATH в shebang | все исполняемые shell-скрипты | системная утилита |
| `ln` | создание символической ссылки для проверки обхода symlink-файлов | test-structure-parser.sh | POSIX-утилита; доступна в Unix-подобных средах и Git for Windows |
| `install`, `cp`, `rm`, `mv`, `mkdir`, `ls` | установка, откат и проверка файлов | manifest-init.sh, test-скрипты | coreutils / Git for Windows |

## 1. Исключённые зависимости

- `python` — удалён из verify.sh (fixture-генератор переписан на
  Bash/awk); зависимостью не является и регистрироваться не должен.

## 2. Границы

Реестр описывает зависимости инфраструктуры репозитория Manifest.
Он не распространяется на подключаемые проекты и не входит в
дистрибутив manifest-init.
