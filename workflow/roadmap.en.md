# Roadmap

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.1.0**  
> **Updated: 2026-11-22**  

# Description
Planned work for the Manifest workflow. Implemented items are marked
as such; the rest remain future deliverables.

## 1. Verification process

### 1.1. Commit — implemented

The model is required to commit; the requirement is recorded in
`workflow/agent-rules.ru.md` (§ Commits), distributed to connected
projects by the `add-init-temp-and-commit-distribution` change.

### 1.2. Verification — implemented

`scripts/verify.sh` runs as a pre-commit hook (`scripts/hooks/pre-commit`);
the requirement to pass it before committing is part of the same
agent rules. The hook is the project's own dev infrastructure and is
excluded from the framework distribution (see 1.6).

### 1.3. Script — implemented

Universal format; all machine-checkable checks:

* presence of metadata fields, headings, section numbering,
  `Version` / `Updated` formats;
* content (composition) is NOT checked — it varies per project;
* version and date are checked via git delta (staged vs HEAD):
  content changed → `Updated` must differ; `approved` → `Version`
  must differ; `draft` → version not checked;
* `Type` is the gate that selects the check set.

### 1.4. Second hook — `commit-msg` — not implemented

Validates the commit message per `commit-rules.md`. Only the
`pre-commit` hook exists; `commit-msg` remains a future deliverable.

### 1.5. Open questions — resolved

* rendering format of the metadata block: blockquotes (current
  practice across `workflow/` files);
* model's obligations (commit, verification) are recorded in the
  agent file (`workflow/agent-rules.ru.md`), not in `AGENTS.md`.

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
