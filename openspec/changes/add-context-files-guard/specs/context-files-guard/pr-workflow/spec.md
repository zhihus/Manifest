## Purpose

Defines the task-branch and PR workflow that separates file-edit authorization (Guard approval) from integration authorization (PR approval) for the protected `Develop` branch.

## ADDED Requirements

### Requirement: Task branches only
The model SHALL NOT work directly on `Develop`. It SHALL create a task branch from the current `Develop` and keep all task commits there, then push the branch and open a PR to `Develop`. The model may update the PR and address feedback.

#### Scenario: Task started
- **WHEN** the model begins work that will touch protected files
- **THEN** it works on a task branch created from current `Develop`, never on `Develop` itself

### Requirement: Merge only through approved PR
Merging into `Develop` SHALL happen only through the hosting platform after user PR review/approval and required checks pass. No direct push or local copy into `Develop`. A changed PR diff requires renewed approval.

#### Scenario: Approved merge
- **WHEN** the user approves the PR and checks pass
- **THEN** the merge is performed via the hosting platform, never by local push into `Develop`

#### Scenario: PR diff changed after approval
- **WHEN** the PR diff changes after the user's approval
- **THEN** renewed approval is required before merge

### Requirement: Separate approval gates
Guard approval SHALL authorize editing a protected file; PR approval SHALL authorize integrating the branch into `Develop`. The two gates MUST be independent: neither implies the other.

#### Scenario: Guard-approved but PR rejected
- **WHEN** a protected-file change was Guard-approved but the PR is rejected or closed
- **THEN** the branch stays isolated on the task branch with no automatic rollback and no merge into `Develop`

### Requirement: Model cannot approve or merge
The model SHALL NOT be able to issue Guard authorization, approve the PR, or merge into `Develop`; these actions belong to the user and the hosting platform respectively.

#### Scenario: Model attempts merge
- **WHEN** the model attempts to merge or push directly into `Develop`
- **THEN** the action is blocked by Git hooks and branch protection
