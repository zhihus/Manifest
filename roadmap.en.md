# Roadmap

> **Status: draft**
> **Type: document**
> **Version: 1.0.0**
> **Updated: 2026-11-07**

# Description
Planned work for the Manifest workflow. Each item is a future deliverable,
not yet implemented.

## 1. Validator script

### 1.1. A single `validate.sh` script — the one source of truth for file
correctness. Two entry points:

* the model runs it proactively after finishing work on a file, before
  committing (primary path);
* the git pre-commit hook calls the same script as a safety net (the hook
  carries no logic of its own, only the call).

### 1.2. Platform: one `sh` script. Native on Linux, on Windows via Git Bash
(git hooks already run under Git Bash). No `ps1` — no duplicated logic.

### 1.3. Checks (gated by `Type`):

* always: file name — kebab-case, English, language suffix `.en`/`.ru`;
* `Type: document`: metadata block (Status, Type, Version, Updated),
  `# Description` section, section numbering `1.` / `1.1.`,
  `Version` format `X.Y.Z`, `Updated` format `YYYY-MM-DD`.

### 1.4. Result: `exit 0` — ok; `exit 1` + a concrete message on stderr
(e.g. "file X: missing field `Type`"), which the model reads and fixes.

### 1.5. Open question: where to record the model's obligation to run the
validator after work — in `AGENTS.md` (project rule) or in
`file-structure-rules` (part of the process structure).