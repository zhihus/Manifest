# Manifest and Connected Project Structure

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-24**  

# Description
Proposed minimal repository structure for Manifest and projects connected to it.

## 1. Purpose and scope

This document proposes a consistent file layout for Manifest and connected
projects. The goal is a structure that is simple for people and predictable
for agents and validation scripts.

This is a design proposal. It does not move files or change current templates,
configuration, or rules. Such changes follow approval of the structure.

Manifest remains the source of shared rules. Each connected project owns its
requirements, architecture decisions, tasks, and code. Todoing and OpenSpec
remain independent tools.

## 2. Principles

1. **One file, one responsibility.** Do not duplicate a rule across documents.
2. **Keep the root for essential files.** Ordinary documentation and working
   materials do not belong there.
3. **Separate systems have separate directories.** Manifest settings,
   Todoing data, and OpenSpec artifacts must not be mixed.
4. **Optional components do not create empty directories.** If OpenSpec or
   Todoing is not connected, its directory is absent.
5. **Do not create manual archives without a need.** Git stores history;
   OpenSpec archives changes in its own standard directory.
6. **Never overwrite existing files during connection.** Report conflicts.
7. **Do not duplicate specifications.** OpenSpec stores change requirements;
   architecture documents store durable decisions and project design.

## 3. Proposed connected project structure

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
├── openspec/             # only when OpenSpec is connected
│   ├── config.yaml
│   ├── specs/
│   └── changes/
│
└── .todoing/             # only when Todoing is connected;
                         # contents are owned by Todoing
```

This is the target proposal, not a claim that every listed file is already
included in the current Manifest distribution.

### 3.1. Root files

| File | Single responsibility |
|---|---|
| `AGENTS.md` | Short mandatory agent rules and authority boundaries. |
| `llms.txt` | Project navigation: purpose, directories, build, and document links. |
| `COMMIT_RULES.md` | Commit format and restrictions. |
| `VERSION` | Current project version. |
| `VERSIONING.md` | Version change rules. |
| `RELEASES.md` | Release preparation and publication. |
| `.llmignore` | Restrictions on files agents may read. |

Specialized development, testing, and logging rules are added only when the
corresponding templates are approved and needed by the project. They must not
duplicate `AGENTS.md`.

### 3.2. .manifest directory

This directory belongs to Manifest and contains only connection data and
mechanisms:

- project configuration file;
- permanent Project ID;
- validation script;
- installed Git Hooks.

It does not contain architecture documents, plans, tasks, or specifications.

The configuration file name and format must follow a separately approved
contract. This document does not choose a format before that decision.

### 3.3. docs directory

- `docs/architecture/` — project architecture, accepted decisions,
  contracts, and rationale.
- `docs/plans/` — long-term plans that are not active tasks.

Other directories are created only when a durable need appears. Temporary
notes and execution artifacts do not automatically become permanent docs.

### 3.4. openspec directory

OpenSpec is optional. When used, its own structure remains under OpenSpec
control and is not reshaped by Manifest:

- `specs/` — current requirements;
- `changes/` — active changes and archived changes.

Do not create parallel copies of OpenSpec specifications under `docs/`.

### 3.5. .todoing directory

The directory and its contents belong to Todoing. Manifest interacts with
Todoing only through its public CLI/JSON API and does not edit internal files
or the database directly.

If Todoing is not connected, the directory is not created.

## 4. Sources of truth

| Data | Single source of truth |
|---|---|
| Shared Manifest rules | Manifest repository |
| Manifest connection settings | `.manifest/` |
| Change requirements and scenarios | OpenSpec, when connected |
| Tasks, statuses, and history | Todoing, when connected |
| Code and change history | Git |
| Project architecture decisions | `docs/architecture/` |
| Long-term plans | `docs/plans/` |

If a component is not connected, its responsibilities must not be silently
duplicated in another directory.

## 5. Structure of the Manifest repository itself

Keep the existing primary directories in the Manifest repository:

- `docs/architecture/` — Manifest architecture and integration contracts;
- `docs/plans/` — development plans;
- `docs/templates/` — source templates for connected projects;
- `workflow/` — processes and working rules;
- `openspec/` — specifications for Manifest development;
- `scripts/` — Manifest validation and utility scripts.

Within `docs/architecture/`, gradually group materials by purpose:

- keep primary documents and current decisions at the top level;
- move audits and reviews into `audits/`;
- move integration contracts into `contracts/`;
- move session records and superseded editions into `history/`.

Move documents only after auditing references. Do not delete historical
documents; preserve Git history and update all links when moving them.
A new document must not create a second source of truth.

## 6. Inconsistencies to resolve before changing templates

The current Manifest documents disagree on the mandatory files for a
connected project:

- `docs/project-manifest.md` contains a frozen baseline of ten files;
- `docs/architecture/architecture-brief.ru.md` describes a shorter MVP
  set and notes that some templates do not yet exist;
- `AGENTS.md` and `llms.txt` define their own context and navigation rules.

Do not silently choose one of these lists. Before changing templates, compare
them with the user's latest decisions and reconcile the documents around one
source of truth.

Also clarify which of `AGENTS.md`, `llms.txt`, `VERSION`,
`VERSIONING.md`, `RELEASES.md`, and commit rules are always installed,
and which depend on project type or connected capabilities.

## 7. Adoption sequence

1. Approve the target structure and mandatory file set.
2. Reconcile conflicting architecture documents.
3. Update the `manifest-init` specification and rules.
4. Update templates and structure validation.
5. Test installation on a sample project of each supported type.
6. Apply the structure to new projects after successful validation.

Do not automatically move or restructure existing connected projects.
Migration must be a separate, verifiable operation with a report that
preserves user files.
