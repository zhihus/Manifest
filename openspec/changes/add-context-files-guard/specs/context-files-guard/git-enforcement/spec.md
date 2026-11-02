## Purpose

Enforces authorization at the Git layer: pre-commit/post-commit verification, blocking of mismatched protected changes, integration-branch protection, and partial controls over known bypass vectors.

## ADDED Requirements

### Requirement: Pre-commit verification
Git pre-commit hooks SHALL verify staged protected content before a commit is created. A commit containing extra or mismatched protected changes MUST be blocked, while unrelated staged work is preserved.

#### Scenario: Extra protected change sneaked into commit
- **WHEN** a staged commit includes a protected change not covered by an authorization
- **THEN** the commit is blocked and the reason names the offending path

#### Scenario: Matching protected change passes
- **WHEN** staged protected content exactly matches the active authorization (blob hashes and diff hash)
- **THEN** the commit proceeds and a durable receipt is recorded for post-commit verification

### Requirement: Post-commit verification and consumption
Git post-commit hooks SHALL verify the created commit's parent, tree and diff against the durable pre-commit receipt, then consume the authorization. Post-commit verification MUST NOT attempt to undo a completed commit.

#### Scenario: Post-commit mismatch
- **WHEN** the created commit differs from the verified staged content
- **THEN** the discrepancy is reported, the authorization is invalidated, and the commit is flagged for user review (not silently reverted)

### Requirement: Integration branch protection
The Guard SHALL enforce that work never happens directly on `Develop`: task branches are created from `Develop`, all task commits stay on the task branch, and integration into `Develop` happens only through an approved PR on the hosting platform.

#### Scenario: Commit attempt on Develop
- **WHEN** a commit touching protected files is attempted directly on `Develop`
- **THEN** it is blocked and the user is directed to a task branch

#### Scenario: Direct push to Develop
- **WHEN** a direct or force push to `Develop` is attempted locally
- **THEN** the Git hooks reject it; branch protection (require PR, approval, checks) is additionally configured on the hosting platform

### Requirement: Bypass vectors and their controls
The Guard SHALL apply documented partial controls to known bypass vectors: block known forms of `git commit --no-verify` via PreToolUse, check the effective `core.hooksPath` and reject unexpected values, inspect Bash commands partially (`apply`/`checkout`/`sed` on protected paths), and protect Guard/hook files with checksums validated against a trusted reference.

#### Scenario: Commit with --no-verify
- **WHEN** the model attempts a known form of `git commit --no-verify` that touches protected files
- **THEN** the ZCode PreToolUse hook blocks the command

#### Scenario: Redirected hooks path
- **WHEN** `core.hooksPath` is changed to an unexpected value
- **THEN** the Guard fails closed and protected operations are blocked until the layout is restored

### Requirement: Fail closed
If the Guard, broker, authorization state, Git hooks or approval UI are unavailable or fail verification, the Guard SHALL fail closed: protected-file operations are blocked, unrelated work is unaffected.

#### Scenario: Guard unavailable
- **WHEN** a protected-file operation is requested while the Guard or its state cannot be reached or verified
- **THEN** the operation is denied with a fail-closed error
