# agent-rules-file Specification

## Purpose

The agent-rules-file capability defines the project agent file
`agent-rules`: a plain-structured context file delivered to connected
projects, carrying the framework rules an agent must follow and a
marked block for the project's own preserved rules.

## Requirements

### Requirement: plain structure, no metadata header

The agent file MUST NOT follow `file-structure-rules` (that structure
applies to rule files in `workflow/` only). It MUST be modeled on
`docs/templates/agents.template.md`: plain sections, no metadata
header, no Examples footer. The structure parser MUST NOT be applied
to it.

#### Scenario: file shape

- **WHEN** the agent file is created in a connected project
- **THEN** it contains plain sections starting from the commit rules
  section, with no `# Metadata` header and no parser requirements

### Requirement: minimal first release

The first release of the agent file MUST contain only the commit
rules section (a reference to `commit-rules`) and the empty
preserved-content block. No other file references.

#### Scenario: first release content

- **WHEN** the agent file is inspected
- **THEN** it references only `commit-rules` and contains the
  preserved-content block; no references to files absent from
  `workflow/`

### Requirement: preserved-content block

The agent file MUST contain a block framed by the markers
`<!-- manifest:preserved start -->` and `<!-- manifest:preserved end -->`.
The block is NOT titled "temporary". It holds rules transferred from
the project's original agent file during archive-based replacement.
The marker semantics MUST be documented: content inside came from the
project and is subject to Manifest rules.

#### Scenario: empty block on fresh init

- **WHEN** a project is initialized with no prior agent file
- **THEN** the preserved-content block is present and empty

#### Scenario: block filled on replacement

- **WHEN** an existing agent file is archived and replaced
- **THEN** the transferred substance appears inside the markers as one
  block

### Requirement: substance-only transfer

During archive-based replacement only the substance MUST be
transferred into the preserved block: the rules the model must follow.
The original file's structure (header, fields, footer, service
elements) MUST be cut away.

#### Scenario: transfer of legacy rules

- **WHEN** the original agent file contains a metadata header, a
  footer and several rules
- **THEN** only the rules (rewritten as the model's obligations) enter
  the preserved block; header, fields, footer and service elements do
  not

### Requirement: file name

The project agent file MUST be named `agent-rules`.

#### Scenario: name

- **WHEN** manifest-init writes the agent file into a project
- **THEN** the file is `<project-root>/agent-rules.md`