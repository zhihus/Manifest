# Spec Delta: template-install

## MODIFIED Requirements

### Requirement: Mandatory base set is installed
The system MUST install the mandatory base context file set of exactly five files: AGENTS.md, llms.txt, COMMIT_RULES.md, VERSION, VERSIONING.md.

The system installs exactly five files via the name-mapping table
(design D4). `RELEASES.md` is classified per the Architecture Brief
(§4): part of the mandatory base set, temporarily not installed
because no template exists and none is invented; it is not a
conditional template. Template files reference other context files
only by canonical installed filenames — exactly the names Manifest
installs (`COMMIT_RULES.md`, `VERSIONING.md`) — or the declared
canonical conditional names (`CODE_RULES.md`, `TEST_RULES.md`,
`LOG_RULES.md`), or the canonical base-set name `RELEASES.md`.

#### Scenario: Fresh project

- **WHEN** none of the base set files exist in the project root
- **THEN** all five files are installed from the template source
- **AND** the report lists each installed file

#### Scenario: Canonical reference names

- **WHEN** a template references a base-set file
- **THEN** the reference uses the exact installed filename casing
- **AND** no template references a lowercase variant such as
  `commit-rules.md` or `releases.md`
