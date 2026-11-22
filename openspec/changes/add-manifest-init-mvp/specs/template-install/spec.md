# Spec Delta: template-install

## Purpose

Installing Manifest context files into a project from the single
common MVP template, with strict overwrite protection and conflict
reporting.

## ADDED Requirements

### Requirement: Mandatory base set is installed
The system MUST install the mandatory base context file set: AGENTS.md, llms.txt, COMMIT_RULES.md, VERSION, VERSIONING.md, RELEASES.md.

The system installs the mandatory base context file set defined by
the Manifest brief: `AGENTS.md`, `llms.txt`, `COMMIT_RULES.md`,
`VERSION`, `VERSIONING.md`, `RELEASES.md`.

#### Scenario: Fresh project

- **WHEN** none of the base set files exist in the project root
- **THEN** all six files are installed from the template source
- **AND** the report lists each installed file

### Requirement: Single common MVP template
The system MUST install files from one common template set and MUST NOT use type-specific template sets in the MVP.

The system installs files from one common template set; no
type-specific (code/documentation) template sets exist in the MVP.

#### Scenario: Mixed project

- **WHEN** the project is identified as mixed (code + documentation)
- **THEN** the same common set is installed as for any other project
- **AND** no type-specific files are added

### Requirement: Existing files are never overwritten
The system MUST NOT overwrite or merge an existing project file; an existing target file MUST be left untouched and recorded as a conflict.

The system never overwrites or merges an existing project file; an
existing target file is left untouched and recorded as a conflict.

#### Scenario: Existing AGENTS.md

- **WHEN** `AGENTS.md` already exists in the project root at install
  time
- **THEN** its content is unchanged after the install
- **AND** the file is reported as a name conflict

### Requirement: Conflicts are reported and do not abort the rest
Name conflicts MUST NOT stop installation of the remaining missing files, and every conflict MUST be listed in the final report.

Name conflicts do not stop installation of the remaining missing
files; every conflict is listed in the final report.

#### Scenario: Two of six files exist

- **WHEN** two of the base set files already exist
- **THEN** the four missing files are installed
- **AND** the report lists the two conflicts
- **AND** the command exits with a status reflecting that conflicts
  occurred (non-zero, distinguishable from Preflight failure)

### Requirement: Installed files match the template source content
Installed files MUST be byte-identical copies of the template source files.

Installed files are byte-identical copies of the template source
files; nothing is generated or adapted in place during install.

#### Scenario: Installed file compared to source

- **WHEN** a file is installed
- **THEN** its content equals the corresponding template source file
  content
