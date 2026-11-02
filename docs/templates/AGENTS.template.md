# Project Rules

## Project

Name: **{{PROJECT_NAME}}**.

## Purpose

{{PROJECT_PURPOSE}}{% if ENTRY_POINT %} Entry point: `{{ENTRY_POINT}}`.{% else %} Entry point: not established.{% endif %}

## Context

{{PROJECT_CONTEXT}}

## Files

* Read `.llmignore` first; access ignored paths only with explicit permission.
* Do not change files or architecture outside the current task without user request.
* Read files referenced here only at the relevant stage.

## Rules

* Current task = the single task currently requested by the user.
* Before code → write a test reproducing the issue or verifying expected behavior.
* No test, no code.
* No implementation TODO list without user approval.
* Copy-paste output (prompts, commands, code, config) → fenced code block, not plain text.
* Code → `CODE_RULES.md`.
* Logging → `LOG_RULES.md`.

## Git

* `COMMIT_RULES.md`
* `RELEASES.md`

## Versioning

* `VERSIONING.md`

## Testing

* `TEST_RULES.md`