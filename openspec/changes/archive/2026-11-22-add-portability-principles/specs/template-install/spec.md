# Spec Delta: template-install

## MODIFIED Requirements

### Requirement: Mandatory base set is installed
The system MUST install exactly five base files: `AGENTS.md`,
`llms.txt`, `COMMIT_RULES.md`, `VERSION`, and `VERSIONING.md`.
Template references MUST use canonical installed filenames.
`RELEASES.md` is part of the mandatory base set per Architecture
Brief §4 but is not installed until a template exists; it is not
conditional. Conditional references use `CODE_RULES.md`,
`TEST_RULES.md`, and `LOG_RULES.md`.

#### Scenario: Fresh project

- **WHEN** none of the base set files exist in the project root
- **THEN** all five files are installed from the template source
- **AND** the report lists each installed file

#### Scenario: Canonical reference names

- **WHEN** a template references a base-set file
- **THEN** the reference uses the exact installed filename casing
- **AND** no template references a lowercase variant such as
  `commit-rules.md` or `releases.md`
