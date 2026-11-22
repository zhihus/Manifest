# template-install Specification

## Purpose
Installing Manifest context files into a project from the single
common MVP template, with strict overwrite protection and conflict
reporting.

## Requirements

### Requirement: Mandatory base set is installed
The system MUST install exactly the five currently available MVP base
files: AGENTS.md, llms.txt, COMMIT_RULES.md, VERSION, and VERSIONING.md.
RELEASES.md is also a mandatory Manifest base document, but is not
installed until its template exists; it is not a conditional file.

The system installs exactly five files via the name-mapping table
(design D4); RELEASES.md is excluded from the MVP install set because
no template exists and none is invented.

#### Scenario: Fresh project
- **WHEN** none of the five currently installable base files exist in the project root
- **THEN** all five files are installed from the template source
- **AND** the report lists each installed file
- **AND** RELEASES.md is not installed while its template is unavailable

#### Scenario: Canonical reference names
- **WHEN** a template references a base-set file
- **THEN** the reference uses the exact canonical filename
- **AND** no template references a lowercase variant such as commit-rules.md or releases.md

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
- **WHEN** AGENTS.md already exists in the project root at install time
- **THEN** its content is unchanged after the install
- **AND** the file is reported as a name conflict

### Requirement: Conflicts are reported and do not abort the rest
Name conflicts MUST NOT stop installation of the remaining missing files, and every conflict MUST be listed in the final report.

Name conflicts do not stop installation of the remaining missing
files; every conflict is listed in the final report.

#### Scenario: Two of five files exist
- **WHEN** two of the five installable base files already exist
- **THEN** the three missing files are installed
- **AND** the report lists the two conflicts
- **AND** the command exits with a status reflecting that conflicts occurred (non-zero, distinguishable from Preflight failure)

### Requirement: Placeholders are resolved before install
The system MUST NOT install a file that still contains an unresolved template placeholder.

Placeholders are filled deterministically (design D7): PROJECT_NAME
and PROJECT_PURPOSE from interview data (empty purpose becomes
"Purpose: not established."), INITIAL_VERSION with default 0.1.0
unless overridden, ENTRY_POINT and BUILD_METHOD conditionals via
the templates' own fallback branches, PROJECT_CONTEXT and
PROJECT_DIRECTORIES with "Not established.".

#### Scenario: Unfilled mandatory placeholder
- **WHEN** rendering would leave a {{PLACEHOLDER}} marker in an installed file
- **THEN** the file is not installed
- **AND** the command exits non-zero with INSTALL_CORRUPT

#### Scenario: No interview data for purpose
- **WHEN** no purpose is provided in the interview or by flag
- **THEN** the installed files contain the neutral line "Purpose: not established." instead of {{PROJECT_PURPOSE}}

### Requirement: Installed files are verified against the template render
Installed files MUST be verified by byte-comparing each installed file with a fresh deterministic render of its source template, and any difference MUST abort with a reported file name.

Each source template is rendered with the same substitution values to
a temporary location outside the project and compared with the
installed file; on difference the command prints INSTALL_CORRUPT
<file> and exits non-zero, removing the temp render.

#### Scenario: Installed file compared to render
- **WHEN** a file is installed
- **THEN** its content byte-equals the deterministic render of its source template
- **AND** no temporary render file is left in the project
