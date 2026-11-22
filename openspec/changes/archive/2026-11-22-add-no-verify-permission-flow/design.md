# Design

## Context

`scripts/hooks/pre-commit` is a thin wrapper; all gate logic lives in
`scripts/verify.sh`. The `rules` branch of `main()` currently fails
with a single hard message. A bash hook can only print text — it
cannot open a harness permission dialog; the agent reading its output
must do that. See proposal.md — Why.

## Goals / Non-Goals

Goals:
- The mismatch output names both files and both sanctioned remediation
  paths, including the exact flag `--no-verify`.
- No user bypass without an explicit permission request.

Non-Goals:
- Changing parser logic or the verify test suite.
- Any interactive UI inside the hook itself.

## Decisions

- **Keep the exit code non-zero on mismatch.** The gate still blocks;
  only the message changes from a dead end to an instruction block.
  Alternative (exit 0 with a warning) rejected: it lets unattended
  commits slip through.
- **Structured plain-text instruction, not machine protocol.** The
  agent reads the hook output as text; a numbered two-path block is
  reliable across harnesses. A JSON protocol was rejected as
  over-engineering for one consumer.
- **The instruction names the flag explicitly** (`--no-verify`) and
  states that the agent must request user permission through the
  harness's standard permission mechanism first. Rationale: without
  the explicit sentence the agent's most likely behavior is a silent
  bypass.

## Risks / Trade-offs

- [Agent ignores the instruction and bypasses silently] → The
  instruction is imperative and user-facing; commit message of a
  bypassed commit is visible in history for audit.
- [Legitimate parser update tasks now see a longer message] → The
  block is short (under 10 lines).

## Migration Plan

Single-script change, no migration. Rollback: revert the commit.

## Open Questions

None.
