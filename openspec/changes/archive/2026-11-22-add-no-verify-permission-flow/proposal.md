# Proposal

## Why

When `workflow/file-structure-rules.ru.md` changes without a matching
`scripts/structure-parser.sh` change, `verify.sh` hard-fails with a
one-line message. The agent has no sanctioned way forward: it either
silently bypasses the gate with `--no-verify` (undocumented, no user
consent) or stalls. The gate should teach the agent the two legitimate
paths instead of just blocking.

## What Changes

- Replace the hard-fail "rules changed, parser not updated" branch in
  `scripts/verify.sh` with an action-required instruction block that
  tells the agent to:
  1. bring the parser in line with the structure-rules changes and
     commit both files together, or
  2. if the rules change genuinely requires no parser change, request
     the user's permission to commit with `--no-verify` via the
     harness's standard permission-request mechanism.
- The hook itself (`scripts/hooks/pre-commit`) stays a thin wrapper;
  all logic remains in `verify.sh`.
- The permission dialog is created by the agent following the printed
  instruction (a bash hook can only print text), so the instruction
  must be explicit and structured.

## Capabilities

### New Capabilities
- `verify-gate`: behavior of the pre-commit verification gate — how
  `verify.sh` reports a rules/parser mismatch and what remediation
  paths it sanctions (parser update, or user-approved `--no-verify`).

### Modified Capabilities

## Impact

- `scripts/verify.sh` — the `rules` branch of `main()`.
- Agent behavior on every commit that touches the structure rules.
- No API, dependency, or distribution changes (`verify.sh` and
  `scripts/hooks/` remain development-only, excluded from
  manifest-init dist).
