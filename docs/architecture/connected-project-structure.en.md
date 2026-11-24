# Approved Structure of Manifest and Connected Projects

# Metadata
> **Status: approved**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-24**  

# Description
Approved minimal repository structure for Manifest and projects connected to it.

## 1. Purpose

This document records the agreed structure of Manifest itself and projects connected to it.

It defines the location of primary files and directory ownership. It does not require every component to be installed in every project: OpenSpec and Todoing are optional integrations.

Manifest provides shared rules and connection mechanisms. A connected project owns its code, requirements, architecture decisions, and plans. Todoing, OpenSpec, and Git retain their separate responsibilities.

## 2. Core principles

1. Each file has one responsibility and does not duplicate other documents.
2. The project root contains only primary files.
3. Documentation, Manifest settings, tasks, and requirements are kept separate.
4. Optional components do not create empty directories.
5. Git stores change history; OpenSpec changes are archived through its standard mechanism.
6. Manifest connection never overwrites existing files. Conflicts are reported to the user.
7. OpenSpec requirements and Todoing tasks are not copied into project docs.

## 3. Connected project structure

```text
project/
├── AGENTS.md
├── llms.txt
├── COMMIT_RULES.md
├── VERSION
├── VERSIONING.md
├── RELEASES.md
├── .llmignore
│
├── .manifest/
│   ├── <project-config>
│   ├── project-id
│   ├── validate.sh
│   └── hooks/
│       ├── pre-commit
│       └── commit-msg
│
├── docs/
│   ├── architecture/
│   └── plans/
│
├── openspec/             # when OpenSpec is connected
│   ├── config.yaml
│   ├── specs/
│   └── changes/
│
└── .todoing/             # when Todoing is connected
```

### 3.1. Primary root files

| File | Responsibility |
|---|---|
| AGENTS.md | Core agent rules and authority boundaries. |
| llms.txt | Concise project map and document links. |
| COMMIT_RULES.md | Commit format and execution rules. |
| VERSION | Current project version. |
| VERSIONING.md | Version change rules. |
| RELEASES.md | Version preparation and release rules. |
| .llmignore | Restrictions on files agents may read. |

These files form the primary visible root layout. The final list of mandatory context files is governed by a separate approved Manifest decision. This decision does not revoke or shorten the previously approved list of mandatory files, including specialized development, testing, and logging rules. Until conflicts are resolved separately, the existing frozen list in docs/project-manifest.md remains in force. Specialized documents must not duplicate AGENTS.md.

### 3.2. .manifest directory

This directory belongs to Manifest and contains only connection data and mechanisms:

- connected project configuration;
- permanent project identifier;
- structure and settings validation script;
- installed Git Hooks.

Architecture documents, plans, tasks, and requirements do not belong here.

The exact configuration file name and format are defined by a separate Manifest contract.

### 3.3. docs directory

- docs/architecture/ — project design, architecture decisions, contracts, and their rationale.
- docs/plans/ — long-term plans that are not active tasks.

Other permanent documentation directories are created only when a durable need exists.

### 3.4. openspec directory

OpenSpec is optional and retains its own structure:

- specs/ — current requirements;
- changes/ — active changes and archived changes.

Manifest does not create parallel copies of OpenSpec specifications under docs/.

### 3.5. .todoing directory

This directory belongs to Todoing. Tasks, statuses, and history are managed by Todoing. Manifest interacts with it through the public Todoing interface and does not edit internal data directly.

If Todoing is not connected, the directory is absent.

## 4. Sources of truth

| Information | Source of truth |
|---|---|
| Shared rules and connection mechanisms | Manifest repository |
| Project connection settings | .manifest/ |
| Requirements and change scenarios | OpenSpec, when connected |
| Tasks, statuses, and history | Todoing, when connected |
| Code and change history | Git |
| Project architecture decisions | docs/architecture/ |
| Long-term plans | docs/plans/ |

The same information must not be independently maintained in multiple places.

## 5. Manifest repository structure

The Manifest repository retains these primary directories:

- docs/architecture/ — Manifest architecture, decisions, and integration contracts;
- docs/plans/ — Manifest development plans;
- docs/templates/ — file templates for connected projects;
- workflow/ — working rules and processes;
- openspec/ — Manifest requirements and changes;
- scripts/ — Manifest utility and validation scripts.

### 5.1. Architecture document organization

The following organization applies within docs/architecture/:

```text
docs/architecture/
├── primary documents and current decisions
├── audits/       # reviews and audits
├── contracts/   # integration contracts
└── history/     # records and superseded editions
```

Primary architecture documents remain at the top level. Audits, contracts, and historical materials are placed in their respective directories.

Existing documents are moved separately, only after checking references, preserving Git history, and updating all links. Historical documents are not deleted.

## 6. Application rules

1. This is the target structure for new projects connected to Manifest.
2. If OpenSpec or Todoing is absent, its directory is not created.
3. Connecting Manifest does not overwrite user files.
4. Existing projects are not restructured automatically. Migration is a separate, verifiable operation with a report that preserves user files.
5. Manifest templates, rules, and validation scripts must conform to this structure.
6. If Manifest documents conflict, this approved architecture decision takes precedence. Dependent documents and templates are aligned through separate changes.

## 7. Adoption steps

1. Reconcile the existing list of mandatory files and templates with this structure.
2. Align the manifest-init specification and rules.
3. Update templates and structure validation.
4. Test connection on sample projects.
5. Prepare a separate migration procedure for existing projects.

Approval of this structure does not automatically execute these changes. Each adoption stage must be verifiable and preserve existing user data.
