## Purpose

Defines which files are protected from unsanctioned AI changes, how protection policy is configured and versioned, and which operations count as protected.

## ADDED Requirements

### Requirement: Protected-file policy file
The Guard SHALL read its protection policy from a single policy file (`protected-files.json`) stored under Git, listing protected file paths. The policy file itself SHALL be protected by the Guard.

#### Scenario: Policy file lists protected paths
- **WHEN** the Guard evaluates an operation on a path listed in the policy file
- **THEN** the operation is treated as a protected operation and requires authorization

#### Scenario: Policy file is itself protected
- **WHEN** an operation targets the policy file
- **THEN** the operation requires authorization like any other protected file

### Requirement: MVP scope of protection
The Guard SHALL protect tracked UTF-8 text files only, comparing Git blob bytes/hashes. The Guard MUST NOT silently discard unrelated work when rejecting protected operations.

#### Scenario: Binary or untracked file
- **WHEN** an operation targets an untracked or binary file listed in the policy
- **THEN** the Guard denies it as unsupported and reports the reason instead of partially applying policy

#### Scenario: Unrelated staged work preserved
- **WHEN** a commit is blocked because of a mismatched protected change
- **THEN** unrelated staged changes remain staged and intact

### Requirement: Model cannot self-authorize
The model SHALL NOT be able to issue, extend or forge authorization. Authorization MUST originate from a confirmed native user interaction captured outside the model's control.

#### Scenario: Model claims approval in chat
- **WHEN** the model asserts in chat that the user approved a protected-file change
- **THEN** the Guard treats the operation as unauthorized and blocks it
