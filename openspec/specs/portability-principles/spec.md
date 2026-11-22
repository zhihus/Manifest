# portability-principles Specification

## Purpose

Defines autonomy and portability requirements for Manifest's own
public files, scripts, and templates. These requirements apply to the
Manifest repository and do not impose obligations on connected
projects.

## Requirements

### Requirement: Check scope follows installation and distribution

The autonomy checks MUST cover every file Manifest installs into
connected projects, every file Manifest distributes to them, and
Manifest's navigation files (AGENTS.md and llms.txt).

Scope entry is automatic: a file is checked as soon as it becomes
installed or distributed. The current explicit scope is maintained by
the verification implementation. Decision records, local harness
context, and local machine configuration stay outside the scope.

#### Scenario: Machine path in a public file
- **WHEN** a public file contains a machine-specific absolute path
- **THEN** the automated check reports the file and line
- **AND** exits non-zero

#### Scenario: Clean tree
- **WHEN** no public file contains forbidden content
- **THEN** the automated check exits zero

#### Scenario: File becomes distributed
- **WHEN** a file starts being installed or distributed to connected projects
- **THEN** it enters the automated check scope without a separate scope decision

### Requirement: Public files carry no model- or harness-specific instructions

Public files MUST NOT contain instructions or details specific to one
AI model or one AI harness.

Approved architecture decisions and local OpenSpec configuration are
decision/context records, not public framework files, and are outside
the check scope.

#### Scenario: Model name in a public file
- **WHEN** a public file in the checked scope names a specific model or harness
- **THEN** the automated check reports it and exits non-zero

### Requirement: Unrelated-project mentions receive automated and human review

Public files MUST NOT reference projects unrelated to the Manifest
ecosystem. The automated check MUST enforce its closed mechanical
pattern list, and a human reviewer MUST review the public-file scope
for mentions where no mechanical definition exists.

References to Manifest ecosystem components named in the approved
architecture are allowed.

#### Scenario: Unrelated project mention
- **WHEN** a public file mentions an unrelated external project
- **THEN** the automated check reports it when it matches a closed pattern
- **AND** mentions outside those patterns are covered by mandatory human review

### Requirement: Manifest documents are maintained in two editions

Manifest documents in the public-file scope MUST be maintained in
Russian (authoritative) and English (translation) editions, and their
content MUST correspond.

The automated check verifies file pairing in both directions.
Content correspondence is verified by human review.

#### Scenario: English edition without Russian sibling
- **WHEN** an English document in the public-file scope has no matching Russian edition
- **THEN** the automated check reports the file and exits non-zero

#### Scenario: Russian edition without English sibling
- **WHEN** a Russian document in the public-file scope has no matching English edition
- **THEN** the automated check reports the file and exits non-zero

#### Scenario: Paired editions
- **WHEN** a document exists in both Russian and English editions
- **THEN** the bidirectional pairing check passes
- **AND** content correspondence is covered by human review

### Requirement: Scripts are portable Bash scripts without GNU-specific utility dependencies

Repository scripts MUST run as portable Bash scripts without
GNU-specific utility dependencies, including GNU-only find and head
options. Every external binary invoked by scripts/*.sh or hooks under
scripts/hooks/ MUST have a register entry recording its purpose,
scope, and detection method. Invoking an undeclared binary is a
violation.

#### Scenario: Undeclared binary
- **WHEN** a script invokes an external binary absent from the register
- **THEN** the automated check reports it and exits non-zero

#### Scenario: Perl rendering dependency documented
- **WHEN** manifest-init renders templates with Perl
- **THEN** the register documents Perl with its purpose and scope

### Requirement: Shell dependency scan limits require human review

The automated command-position scanner is not a complete Bash parser
and only flags external command tokens resolvable in the current PATH.
A human reviewer MUST inspect changed infrastructure scripts for
invocations outside the scanner's supported grammar and for
platform-specific commands unavailable in the current PATH.

#### Scenario: Shell construct beyond scanner grammar
- **WHEN** an infrastructure script uses command invocation syntax outside the scanner's supported grammar
- **THEN** the reviewer inspects the command and confirms its dependency register entry

### Requirement: Repository verification includes automated autonomy checks

The repository verification script MUST include the autonomy and
privacy checks of this capability and MUST fail with a reported file
and line on any violation.

Findings that require judgment are routed to mandatory human review.
The automated checks never modify files and never impose requirements
on projects that use Manifest.

#### Scenario: Seeded violation is caught
- **WHEN** a forbidden pattern is planted in a fixture copy of a public file and the check runs
- **THEN** the check reports the fixture file and line and exits non-zero

### Requirement: Line endings are predictable

The repository MUST define line-ending behavior in .gitattributes so
that scripts and template bytes are stable across platforms.

Shell scripts and template files are normalized to LF regardless of
the committing platform.

#### Scenario: Template bytes stable across platforms
- **WHEN** the repository is checked out on different platforms
- **THEN** templates, scripts, and hooks have stable LF line endings

### Requirement: External dependency register exists and is referenced

The repository MUST maintain a centralized external dependency
register (Russian authoritative, with an English edition)
documenting each external dependency, its purpose, and its scope of
use, and llms.txt MUST reference it.

Adding a new external binary requires a register entry.

#### Scenario: New dependency added
- **WHEN** a script starts using an external binary
- **THEN** a register entry with tool, purpose, scope, and detection method exists
- **AND** llms.txt references the register
