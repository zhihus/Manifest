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

### 1.1. User actions

#### 1.1.1. The user runs the Manifest initialization with the `manifest-init` skill in a project folder they created themselves.

#### 1.1.2. The user asks the agent to create a project folder and initialize the Manifest framework in it, providing the path to the folder.

### 1.2. Project initialization artifacts

#### 1.2.1. `.manifest/` — the folder, the marker of connection to the Manifest.

#### 1.2.2. `.manifest/hooks/` — contains the active Manifest git hooks.

#### 1.2.3. `.manifest/validate.sh` — the verification script: checks files for compliance with the Manifest rules — presence of metadata fields, headings, section numbering, `Version` and `Updated` formats.

#### 1.2.4. `.manifest/hooks/pre-commit` — before a commit, runs the `validate.sh` script to check the files that go into the commit.

#### 1.2.5. `.manifest/hooks/commit-msg` — fires when the commit message is written: checks that the message complies with the rules of the `commit-rules.md` file.