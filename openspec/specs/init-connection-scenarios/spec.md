# init-connection-scenarios Specification

## Purpose

The init-connection-scenarios capability defines manifest-init
behavior for the three folder cases: empty (or non-existing), non-empty
without framework files, non-empty with framework files.

## Requirements

### Requirement: empty or non-existing folder

When the target folder does not exist or is empty, manifest-init MUST
create the folder, copy the distribution, and activate hooks (current
behavior).

#### Scenario: fresh project

- **WHEN** init runs against a non-existing or empty target folder
- **THEN** the folder is created, `.manifest/` is populated, hooks are
  activated, and the full distribution is present

### Requirement: non-empty folder without framework files

When the folder is non-empty but contains no framework files (no
`.manifest/`, none of the framework context files), manifest-init MUST
augment safely: copy the distribution, add missing sections — and MUST
NOT overwrite the user's existing files.

#### Scenario: foreign files preserved

- **WHEN** the folder contains user files with names unrelated to the
  framework
- **THEN** after init all user files remain unchanged and the
  distribution is added alongside

### Requirement: non-empty folder with framework files

When the folder already contains framework files (`.manifest/` or
conflicting names), manifest-init MUST archive the existing files into
`.manifest/archive/<YYYY-MM-DD-HHMMSS>/`, then recreate the framework
files from templates, transferring only the substance of the original
agent-file rules into the preserved-content block. The agent MUST
report to the user what was archived and what was created. Overwriting
a user file with a conflicting name MUST happen only with explicit
user consent; otherwise stop-and-report. Merging/appending into
existing files is rejected.

#### Scenario: already connected

- **WHEN** `.manifest/` already exists in the target folder
- **THEN** the agent does not re-run a fresh init; it reports the
  state and updates or stops by the user's decision

#### Scenario: archive-based replacement

- **WHEN** the folder contains an existing agent file with its own
  rules
- **THEN** the original is archived unmodified, a new `agent-rules.md`
  is written, and the legacy rules' substance appears inside the
  preserved-content markers

### Requirement: subagent delivery on connection

On connection, the temp boilerplate block MUST be added to the
connected project's subagent definitions (`.zcode/agents/*.md`), if <!-- portability-allow -->
such files exist.

#### Scenario: project has agents

- **WHEN** init connects a project that has `.zcode/agents/*.md` <!-- portability-allow -->
- **THEN** each agent definition gains the temp boilerplate block

### Requirement: distribution exclusions

The init distribution (`skills/manifest-init/dist/`) MUST NOT contain
the Manifest's own dev infrastructure: `scripts/verify.sh` and
`scripts/hooks/` (roadmap §1.6).

#### Scenario: dist contents check

- **WHEN** the distribution is inspected
- **THEN** no file equals the Manifest's `scripts/verify.sh` or
  `scripts/hooks/*`