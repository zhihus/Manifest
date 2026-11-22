# Proposal: add-commit-msg-hook

## Why

The Manifest repository currently validates staged files with a
pre-commit hook, but it does not validate commit messages. The
repository's commit-rules.md defines a conventional format and
breaking-change notation; without an automated gate, malformed
messages can enter the history.

## What Changes

1. Add a commit-msg hook under scripts/hooks/ that validates the
   commit subject against the repository's commit-rules.md.
2. Validate the allowed type, optional scope, breaking-change marker,
   lowercase English subject, and absence of a trailing period.
3. Enforce the paired breaking-change marker and footer requirement.
4. Add a focused regression test script for valid and invalid messages.

## Capabilities

### Modified: commit-message-verification

Commit messages are checked automatically before the commit is
created. The hook reports actionable failures and does not modify the
message or repository state.

## Impact

Only Manifest repository development infrastructure is affected.
No connected-project distribution or commit-rules policy change is
included.
