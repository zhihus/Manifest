# SETTINGS.md

## Project

Name: **{{PROJECT_NAME}}**.

## Environments

* `{{ENVIRONMENT_NAME}}` — {{ENVIRONMENT_DESCRIPTION}}.

## Configuration sources

* `{{CONFIG_FILE_PATH}}` — {{CONFIG_FILE_DESCRIPTION}}.

## Defaults

* `{{SETTING_KEY}}` = `{{SETTING_DEFAULT}}` — {{SETTING_DESCRIPTION}}.

## Feature flags

* `{{FLAG_NAME}}` — {{FLAG_DESCRIPTION}} (default: {{FLAG_DEFAULT}}).

## Paths

* `{{PATH_NAME}}`: `{{PATH_VALUE}}` — {{PATH_DESCRIPTION}}.

## Rules

* Settings are read from the configuration sources above; do not hardcode values that belong in a source.
* A setting change must be documented with its default and the environments it applies to.
* Secrets are never stored in settings files; reference them by name only.