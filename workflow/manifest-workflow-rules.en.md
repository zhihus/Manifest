# Manifest Workflow Rules

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-09**  

# Description
The root document of the Manifest framework: Manifest rules and
processes.

## 1. Initializing a new project

### 1.1. User actions

#### 1.1.1. Running the initialization

The user runs the Manifest initialization with the `manifest-init`
skill in a project folder they created themselves.

#### 1.1.2. Creating the folder via an agent

The user asks the agent to create a project folder and initialize the
Manifest framework in it, providing the path to the folder.

### 1.2. Project initialization artifacts

#### 1.2.1. `.manifest/`

The folder, the marker of connection to the Manifest.

#### 1.2.2. `.manifest/hooks/`

A folder, contains the active Manifest git hooks.

#### 1.2.3. `.manifest/validate.sh`

The verification script: checks files for compliance with the
Manifest rules.

#### 1.2.4. `.manifest/hooks/pre-commit`

Before a commit, runs the `validate.sh` script to check the files
that go into the commit.

#### 1.2.5. `.manifest/hooks/commit-msg`

Fires when the commit message is written: checks that the message
complies with the rules of the `commit-rules.md` file.
