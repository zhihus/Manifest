# Manifest Workflow Rules

> **Status: draft**
> **Type: document**
> **Version: 1.0.0**
> **Updated: 2026-11-07**

# Description
The root document of the Manifest framework. It contains all the Manifest
rules: project connection, file naming, file structure, file versioning,
and the verification process.

## 1. Initializing a new project

### 1.1. What the user does

* The user runs initialization directly in a project folder they created
  themselves.
* Or the user asks the agent to create a project folder and initialize the
  Manifest framework in it, providing the path where the project folder
  will be created.

### 1.2. What is created

* `.manifest/` — marks the project as connected to the Manifest.
* `.manifest/hooks/` — the git hooks folder.
* `.manifest/validate.sh` — the verification script (planned).
* `.manifest/hooks/pre-commit` — calls `validate.sh` on staged files
  (planned).
* `.manifest/hooks/commit-msg` — checks the commit message per
  `commit-rules.md` (planned).
* Hook activation: `git config core.hooksPath .manifest/hooks`.