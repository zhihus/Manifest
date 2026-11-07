# File Naming Rules

> **Status: draft**

Universal file naming rules for any project connected to the Manifest
framework.

## 1. General rules

* **kebab-case, lowercase, no spaces**:
  ✅ `file-naming-rules.md`
  ❌ `File Naming Rules.md`, `fileNamingRules.md`
* Names are in **English**; abbreviations are allowed when unambiguous.
* Hyphens separate words; dots are used only for the extension.
* No dates in names unless the file is an immutable snapshot — then
  `YYYY-MM-DD` goes **last** as a suffix: `report-name-2026-11-07.md`.
* No version numbers in names for versioned content (git carries the
  history). A version suffix is allowed only for released immutable
  artifacts: `report-name-1.0.0.md`.
* One logical document per file; do not embed sequence numbers
  (`report-2.md`) — name by content, not by order of creation.

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

## 5. Requirements to move to the document structure file

> Requirements below were dictated by the user. They are parked here until
> a dedicated document-structure file exists in `workflow/`; that file will
> own this section, and it must be moved there verbatim.

* Every Markdown file has a structure. Minimum: a title — a heading that
  starts with `#` — followed by a status line.
* The status line uses exactly one word: `**Status: draft**`. Nothing else
  is added to it.
* The fixed status set (three base statuses):
  * `draft` — in development;
  * `approved` — approved;
  * `archived` — archived.
* Sections and subsections are numbered hierarchically, dot-separated, by
  depth: `1.` → `1.1.`, `1.2.` → `1.2.1.` (each level adds one component).
