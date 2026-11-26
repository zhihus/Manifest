# temp-folder Specification

## Purpose

The temp-folder capability defines the project scratch folder `temp/`
and its rules, so agents (including subagents) can write freely during
work but never delete, and deletion commands never interrupt the
process.

## Requirements

### Requirement: folder placement and naming

Every Manifest-connected project MUST have a `temp/` folder in the
project root; the name MUST be lowercase `temp`; the folder MUST be
listed in `.gitignore`.

#### Scenario: correct placement

- **WHEN** a project is initialized or inspected
- **THEN** the folder is `<project-root>/temp/` (lowercase) and
  `.gitignore` contains a `temp/` entry

### Requirement: write anything, delete nothing

Agents MAY write any files into `temp/` at any time. Agents MUST NOT
delete anything inside `temp/` — not their own files, not other
agents' files — unless the user explicitly asks.

#### Scenario: agent writes a scratch file

- **WHEN** an agent needs a throwaway script or intermediate artifact
- **THEN** the agent writes it into `temp/` (never elsewhere) and
  continues without asking permission

#### Scenario: agent must not clean up

- **WHEN** an agent considers files in `temp/` stale or leftover
- **THEN** the agent leaves them in place; cleanup is done by the user
  or on an explicit user request only

### Requirement: no console deletion commands

Agents MUST NOT run console deletion commands (`rm`, `Remove-Item`,
equivalents) — they are dangerous, require user confirmation, and
interrupt the process for an undefined time.

#### Scenario: deletion needed

- **WHEN** deletion seems necessary
- **THEN** the agent stops and reports to the user instead of running
  a deletion command

### Requirement: subagent boilerplate block

The temp rule file MUST contain one standard boilerplate block
(2–3 lines: temp/ exists; write anything; delete nothing; no deletion
commands). This block is the single source of the text delivered to
subagents: it MUST be wired into subagent definitions, so every
subagent prompt already contains it.

#### Scenario: subagent knows the rule

- **WHEN** a subagent starts working in a connected project
- **THEN** its prompt already contains the boilerplate block from the
  temp rule file (wired at the definition level, not retyped)