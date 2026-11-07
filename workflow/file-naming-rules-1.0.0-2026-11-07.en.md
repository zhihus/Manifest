# File Naming Rules

> **Status: draft**

Universal file naming rules for any project connected to the Manifest
framework.

## 1. General rules

* Names in English.
* kebab-case, lowercase, no spaces.
* Document files carry version and date in the name (version `X.Y.Z`, date
  ISO `YYYY-MM-DD`).
* File names always carry a language suffix: `en`, or any other at the
  user's request.

### Correct

✅ `file-naming-rules-1.0.0-2026-11-07.en.md`
✅ `file-naming-rules-1.0.0-2026-11-07.ru.md`

### Incorrect

❌ `File Naming Rules-1.0.0-2026-11-07.en.md`
❌ `fileNamingRules-1.0.0-2026-11-07.en.md`
❌ `file-naming-rules.en.md`
❌ `file-naming-rules-1.0.0-07.11.2026.en.md`
❌ `файл-именования-1.0.0-2026-11-07.en.md`
❌ `file-naming-rules-1.0.0-2026-11-07.md`
❌ `file-naming-rules-1.0.0-2026-11-07.EN.md`
❌ `file-naming-rules-en-1.0.0-2026-11-07.md`

## 2. Language suffixes

* Default (no suffix): the English original — `README.md`.
* When both language versions exist, the English file carries `.en`:
  `README.en.md` + `README.ru.md`.
* The `.en.md` file is authoritative; `.ru.md` files are user-facing
  copies and are excluded from agent context by the `*.ru.md` pattern in
  `.llmignore`.

## 3. Directory-specific conventions

* `docs/plans/`: `plan-<topic>[-stage-N].en.md` (+ `.ru.md` twin).
* `openspec/changes/<change-name>/`: artifact names are fixed by the
  OpenSpec pipeline — `proposal.md`, `design.md`, `tasks.md`, `verify.md`
  (never localized or renamed).
* Specs: `openspec/specs/<capability>/spec.md`.
* Test/run artifacts: `test-run-reports/` — `<what>-<version>.md`
  (e.g. `reviewer-summary-report-1.0.0.md`).

## 4. Code and scripts

* Scripts and sources follow the language's dominant convention of the
  project they live in; in doc-only projects, shell scripts use
  kebab-case: `check-compression.sh`.
* Temporary files live only in `temp/` (gitignored) and are never named
  as if they were project artifacts.
