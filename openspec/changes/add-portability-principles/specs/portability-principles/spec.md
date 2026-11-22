# Spec Delta: portability-principles

## Purpose

Autonomy and portability as explicit, mechanically checked
requirements for Manifest's own public files, scripts, and templates.
The requirements apply to the Manifest repository itself; they never
impose obligations on projects that use Manifest.

## ADDED Requirements

### Requirement: Check scope follows installation and distribution
The autonomy checks MUST cover every file Manifest installs into
connected projects, every file Manifest distributes to them, and
Manifest's navigation files (`AGENTS.md`, `llms.txt`).

Scope entry is automatic: a file is checked as soon as it becomes
installed or distributed. The checked set is a closed list maintained
in the check implementation; decision records, local harness context,
and local machine configuration stay outside the scope.

#### Scenario: Machine path in a public file

- **WHEN** a public file contains a path like `C:\Users\…` or
  `/home/<user>/…`
- **THEN** the automated check reports the file and line
- **AND** exits non-zero

#### Scenario: Clean tree

- **WHEN** no public file contains forbidden content
- **THEN** the automated check exits zero

#### Scenario: File becomes distributed

- **WHEN** `workflow/agent-rules` starts being distributed to
  connected projects
- **THEN** the file is checked by the autonomy checks without a
  separate scope decision

### Requirement: Public files carry no model- or harness-specific instructions
Public files MUST NOT contain instructions or details specific to one AI model or one AI harness.

Model and harness facts recorded as approved architecture decisions
(`docs/architecture/`, `openspec/config.yaml`) are decision records,
not public framework files, and are outside the check scope. The
task-size calibration rule in `AGENTS.md` is kept and stated without
model or harness identifiers.

#### Scenario: Model name in AGENTS.md

- **WHEN** `AGENTS.md` names a specific model or harness
- **THEN** the automated check reports it and exits non-zero

### Requirement: Unrelated-project mentions are checked mechanically and by human review
Public files MUST NOT reference projects unrelated to the Manifest
ecosystem. The automated check MUST enforce the closed mechanical
pattern list, and a human reviewer MUST review the public-file scope
for mentions where no mechanical definition exists.

References to Manifest ecosystem components named in the approved
architecture are allowed. The human review covers the closed
public-file scope and reports findings like any automated check.

#### Scenario: Unrelated project mention

- **WHEN** a public file mentions an unrelated external project
- **THEN** the automated check reports it when the mention matches a
  closed pattern (e.g. a machine path)
- **AND** mentions outside the closed patterns are covered by the
  mandatory human review of the public-file scope

### Requirement: Manifest documents are maintained in two editions
Manifest documents in the public-file scope MUST be maintained in two
editions — Russian (authoritative) and English (translation) — and
their content MUST correspond.

The automated check verifies file pairing (every English edition has
a `*.ru.md` sibling); content correspondence is verified by human
review. The bilingual requirement is confirmed by the user
(2026-11-22).

#### Scenario: English edition without Russian sibling

- **WHEN** an English document in the public-file scope has no
  matching `*.ru.md` sibling
- **THEN** the automated check reports the file and exits non-zero

#### Scenario: Paired editions

- **WHEN** a document exists as `*.ru.md` and `*.en.md`
- **THEN** the pairing check passes
- **AND** content correspondence is covered by the human review

### Requirement: Scripts are portable Bash scripts without GNU-specific utility dependencies
Repository scripts MUST run as portable Bash scripts without GNU-specific utility dependencies, and every external binary they invoke MUST be declared in the external dependency register with its purpose and scope.

Repository infrastructure scripts include `scripts/*.sh` and hooks under `scripts/hooks/`, including extensionless hooks. A declared dependency entry
records the tool, its purpose, the scripts using it, and the detection
method. Using an undeclared external binary is a violation. The
command-position scanner is not a complete Bash parser; a human
reviewer MUST inspect changed scripts for invocations outside its
supported grammar.

#### Scenario: Undeclared binary

- **WHEN** a script invokes an external binary absent from the
  register
- **THEN** the automated check reports it and exits non-zero

#### Scenario: Perl rendering dependency documented

- **WHEN** `manifest-init` renders templates with Perl
- **THEN** the register documents Perl with its purpose (template
  rendering) and scope (manifest-init only)

### Requirement: Repository verification includes automated autonomy checks
The repository verification script MUST include the autonomy and
privacy checks of this capability and MUST fail with a reported file
and line on any violation.

Findings that require judgment are routed to the mandatory human
review. The automated checks never modify files and never impose
requirements on projects that use Manifest.

#### Scenario: Seeded violation is caught

- **WHEN** a forbidden pattern is planted in a fixture copy of a
  public file and the check runs
- **THEN** the check reports the fixture file and line and exits
  non-zero

### Requirement: Line endings are predictable
The repository MUST define line-ending behavior in `.gitattributes` so that scripts and template bytes are stable across platforms.

Shell scripts (`*.sh` and `scripts/hooks/*`, including the
extension-less `pre-commit`), and template files are normalized to LF
regardless of the committing platform; byte-level comparisons in
manifest-init rely on this stability.

#### Scenario: Template bytes stable across platforms

- **WHEN** the repository is checked out on different platforms
- **THEN** `docs/templates/*`, `scripts/*.sh`, and `scripts/hooks/*`
  have identical bytes

### Requirement: External dependency register exists and is referenced
The repository MUST maintain a centralized external dependency register (RU authoritative, with an EN edition) documenting each external dependency, its purpose, and its scope of use, and `llms.txt` MUST reference it.

The register is the single source for what the infrastructure may
invoke; adding a new external binary requires a register entry.

#### Scenario: New dependency added

- **WHEN** a script starts using an external binary
- **THEN** a register entry with tool, purpose, scope, and detection
  method exists
- **AND** `llms.txt` references the register
