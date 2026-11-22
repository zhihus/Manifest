# Design: add-commit-msg-hook

## Context

Manifest already stores its own pre-commit hook in
scripts/hooks/pre-commit. Roadmap item 1.4 calls for a second hook,
commit-msg, to validate messages against the repository's root
commit-rules.md.

## Goals / Non-Goals

**Goals:**
- Enforce the mechanically decidable parts of the existing message
  format before Git creates a commit.
- Keep the hook portable to the repository's supported Bash 3.2
  baseline.
- Keep the hook read-only and provide actionable diagnostics.
- Test valid, invalid, and breaking-change message cases.

**Non-Goals:**
- Change commit-rules.md or the universal template.
- Enforce imperative mood or singular grammar algorithmically.
- Enforce the soft 50-character subject guidance as a hard limit.
- Install or configure Git hooks in a user's local Git configuration.
- Change merge policy or connected-project behavior.

## Decisions

- D1. Implement scripts/hooks/commit-msg as a standalone Bash script.
  It receives the message-file path through Git's standard first
  argument. Invalid invocation exits 2; invalid message exits 1;
  valid message exits 0.
- D2. Validate the allowed type list, optional lowercase scope,
  required separator, lowercase ASCII subject, non-empty subject,
  and no trailing period. The subject length remains advisory.
- D3. Enforce the paired breaking-change syntax: header ! and a
  non-empty BREAKING CHANGE: footer must either both exist or both
  be absent.
- D4. Do not attempt natural-language validation of imperative mood,
  singular wording, or semantic accuracy. These remain review checks.
- D5. Add scripts/test-commit-msg.sh. It invokes the hook against
  temporary message files and verifies both exit status and that
  rejected input is unchanged.
- D6. Use only Bash built-ins in the hook; the test may use already
  registered infrastructure utilities.

## Risks / Trade-offs

A structural validator cannot reliably determine grammatical mood
or semantic correctness. The hook makes this boundary explicit and
leaves those checks to review.

## Unresolved Questions

None.
