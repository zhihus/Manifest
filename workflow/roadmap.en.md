# Roadmap

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-10**  

# Description
Planned work for the Manifest workflow. Each item is a future
deliverable, not yet implemented.

## 1. Verification process

### 1.1. Commit

The model is required to commit — the requirement is recorded in
context files (which files — to be decided later).

### 1.2. Verification

The model is required to run the verification script before
committing — the requirement is recorded in context files (which
files — to be decided later).

### 1.3. Script

Universal format; all machine-checkable checks:

* presence of metadata fields, headings, section numbering,
  `Version` / `Updated` formats;
* content (composition) is NOT checked — it varies per project;
* version and date are checked via git delta (staged vs HEAD):
  content changed → `Updated` must differ; `approved` → `Version`
  must differ; `draft` → version not checked;
* `Type` is the gate that selects the check set.

### 1.4. Second hook — `commit-msg`

Validates the commit message per `commit-rules.md`.

### 1.5. Open questions

* rendering format of the metadata block (table / `<br>` / separate
  blockquotes);
* where to record the model's obligations (commit, verification) —
  in `AGENTS.md` or in the rule files.

### 1.6. Distribution build — exclusions

manifest-init `dist/` must not contain the Manifest's
`scripts/verify.sh` and `scripts/hooks/`: they are the project's own
dev infrastructure, not the framework. The future change that fills
`dist/` must include an acceptance scenario: `dist/` contains none
of these files.

### 1.7. Script extensions

Extension points for the structure parser beyond the MVP (the MVP
takes a single file):

* directory walk — check all files, not one;
* scheduled runs.

## 2. Doc projects

### 2.1. Rules template for doc projects

`doc-content-rules.template.md` — a rules template for
**documentation** projects (projects that produce documentation, not
code). Content:

* rules for documentation projects (analog of
  `code-rules.template.md`, but for documentation): Clarity, Accuracy,
  Completeness, Consistency, Structure, Change Discipline,
  Verification;
* temporary context-files protection block: when modifying
  agent/rules files — show the changes + review + explicit user
  consent before commit (until a Git Hook exists);
* git workflow — unresolved (see 2.2).

Status: **not implemented** — the template in
`docs/templates/doc-content-rules.template.md` is a `{{PENDING}}`
stub; it counts as done only when all points, including the git
workflow, are complete.

### 2.2. Open questions

* git workflow for documentation projects (branch per task, merge
  into `develop`, stop-and-report): where to add it — unresolved;
  possibly a separate agent file;
* separate project-context file for documentation projects: possibly
  an agent file; unresolved.
