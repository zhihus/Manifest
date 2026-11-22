# commit-message-verification Specification

## Purpose

Validates Manifest repository commit messages before Git creates a
commit, using the repository's commit-rules.md.

## Requirements

### Requirement: Commit messages conform to repository commit rules

The commit-msg hook MUST reject a message whose first line does not
match the required format and allowed type list in commit-rules.md.
Scope is optional and, when present, MUST be a lowercase stable
identifier. The subject MUST be non-empty lowercase English text and
MUST NOT end with a period. The 50-character subject guidance is a
soft limit and MUST NOT be enforced as a hard failure.

The hook MUST enforce that a breaking-change marker (!) and a
non-empty BREAKING CHANGE: footer are present together. It MUST reject
either one without the other.

The hook validates structural, mechanically decidable rules only.
Imperative mood, singular wording, logical commit scope, and semantic
accuracy remain review responsibilities.

#### Scenario: Valid ordinary commit
- **WHEN** a message has an allowed type, optional valid scope, and a non-empty lowercase subject
- **THEN** the hook exits zero

#### Scenario: Invalid message format
- **WHEN** the first line does not match the required format or uses an unknown type
- **THEN** the hook exits non-zero and explains the expected format

#### Scenario: Invalid subject
- **WHEN** the subject is empty, contains uppercase or non-English letters, or ends with a period
- **THEN** the hook exits non-zero and identifies the subject violation

#### Scenario: Breaking marker without footer
- **WHEN** the header contains ! but no non-empty BREAKING CHANGE: footer exists
- **THEN** the hook exits non-zero

#### Scenario: Footer without breaking marker
- **WHEN** a non-empty BREAKING CHANGE: footer exists but the header has no !
- **THEN** the hook exits non-zero

#### Scenario: Valid breaking change
- **WHEN** the header contains ! and the message contains a non-empty BREAKING CHANGE: footer
- **THEN** the hook exits zero

### Requirement: Hook failure does not modify the message

The hook MUST only inspect the supplied message file. It MUST NOT
rewrite the message, create commits, or modify repository files.

#### Scenario: Rejected message remains unchanged
- **WHEN** the hook rejects a commit message
- **THEN** the supplied message file remains byte-identical
- **AND** the commit is rejected by Git
