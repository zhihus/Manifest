# verify-gate Specification

## Purpose

Define how the pre-commit verification gate reports a
structure-rules/structure-parser mismatch and which remediation
paths it sanctions.

## Requirements

### Requirement: Action-required output on rules/parser mismatch
When the structure-rules file is changed (against HEAD) and the
structure parser is not, the verify script MUST exit non-zero and
print an instruction block containing both remediation paths:
(a) update the parser to match the rules and commit both files
together; (b) if the rules change requires no parser change, ask the
user for permission to commit with `--no-verify`.

#### Scenario: Rules changed, parser untouched
- **WHEN** a commit changes `workflow/file-structure-rules.ru.md` but not `scripts/structure-parser.sh`, and the pre-commit hook runs
- **THEN** the commit is blocked, the output names both files, and the output lists remediation path (a) and remediation path (b) explicitly

#### Scenario: Rules and parser changed together
- **WHEN** a commit changes both the structure-rules file and the parser, and the parser passes reference and fixture tests
- **THEN** the commit proceeds without any additional prompt

### Requirement: Permission request follows the printed instruction
The instruction block MUST state that the permission dialog is created
by the agent (the hook can only print text) and MUST name the target
flag (`--no-verify`) so the agent can raise a standard harness
permission request to the user.

#### Scenario: Agent follows remediation path (b)
- **WHEN** the agent determines the rules change needs no parser update and follows the printed instruction
- **THEN** the agent asks the user for permission to use `--no-verify` through the harness's standard permission-request mechanism before committing

#### Scenario: Agent cannot skip the user
- **WHEN** the gate blocks the commit with the mismatch instruction
- **THEN** the agent has no sanctioned path to bypass the gate without explicit user permission