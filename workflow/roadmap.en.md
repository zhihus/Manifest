# Roadmap

> **Status: draft**
> **Type: document**
> **Version: 1.0.0**
> **Updated: 2026-11-07**

# Description
Planned work for the Manifest workflow. Each item is a future deliverable,
not yet implemented.

## 1. Verification process

### 1.1. Commit. The model is required to commit — the requirement is
recorded in context files (which files — to be decided later).

### 1.2. Verification. The model is required to run the verification script
before committing — the requirement is recorded in context files (which
files — to be decided later).

### 1.3. Script. Universal format; all machine-checkable checks:

* presence of metadata fields, headings, section numbering, `Version` /
  `Updated` formats;
* content (composition) is NOT checked — it varies per project;
* version and date are checked via git delta (staged vs HEAD): content
  changed → `Updated` must differ; `approved` → `Version` must differ;
  `draft` → version not checked;
* `Type` is the gate that selects the check set.

### 1.4. Second hook — `commit-msg`: validates the commit message per
`commit-rules.md`.

### 1.5. Open questions:

* rendering format of the metadata block (table / `<br>` / separate
  blockquotes);
* where to record the model's obligations (commit, verification) — in
  `AGENTS.md` or in the rule files.