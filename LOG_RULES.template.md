# LOG_RULES.md

## Purpose

Define useful, consistent, secure logging without unnecessary noise or material performance impact.

## Record

Each record contains:

* `timestamp` — event time.
* `level` — severity.
* `component` — source component.
* `event` — stable event name.
* `message` — concise human-readable description.
* `context` — optional diagnostic data.

Use the project's established logging framework and encoding.

## Project format

`[YYYY-MM-DD HH:MM:SS] [LEVEL] [component] message`

Use one component prefix per line.

Established components are defined by the current codebase. Add a component here only when a new component is introduced.

## Rules

* Log failures, important state transitions, recovery, degradation and significant lifecycle boundaries.
* `info` = significant normal event; `warn` = degraded/unexpected condition; `error` = serious failure.
* Include enough context to identify the affected operation/resource.
* Do not duplicate the same failure across layers unless the higher layer adds useful information.
* Never log credentials, secrets or tokens.
* Avoid sensitive data unless explicitly required and safe.
* No per-poll, per-frame, callback, buffer, tick or retry-attempt logging.
* Do not log unchanged state repeatedly.
* Long operations should log meaningful start/end boundaries when needed for diagnosis.
* Logging must not materially affect recording, timing, throughput or recovery behaviour.
* Log only diagnostic information useful for operating or debugging the application.

## Exceptions

Deviate only when required by correctness, security, diagnostics, performance or established project architecture.