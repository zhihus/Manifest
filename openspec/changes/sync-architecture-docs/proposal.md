# Proposal

## Why

Discussions on 20–21.11.2026 produced accepted architecture decisions
(7-role model incl. Tester and Analyst, sequential execution, Todoing
contract, Controlled File Update, backup ownership). The existing
architecture documents (Brief v0.2.0, decisions register, audits) still
carried outdated positions and open questions already resolved by the
user. Unsynchronized documents contradict each other and the actual
agreed state.

## What Changes

- Sync `architecture-brief.ru.md` (v0.2.0 → v0.3.0): roles, sequential
  execution, Todoing integration, context-file protection.
- Sync `architecture-decisions.ru.md`: statuses corrected, resolved
  questions closed, performed analytical work marked as done.
- Mark closed audit findings in `architecture-audit.ru.md` (C-1, E-5,
  E-6) without rewriting the audit.
- Sync `docs/todoing-architecture-decisions.ru.md` (v0.1.0 → v0.2.0)
  with the target Todoing documents in PR #1 (todoing-x).
- Sync `workflow/README.en.md` / `README.ru.md` (1.0.0 → 1.1.0):
  roles, sequential execution, escalation loop.
- Extend `docs/templates/code-test-rules.template.md`: TEST FIRST and
  the Tester role.

## Capabilities

- `architecture-docs` — the architecture document set stays mutually
  consistent and reflects accepted decisions with correct statuses
  (accepted / preliminary / deferred / open / done / not-implemented).

## Out of Scope

- Implementation of any decided functionality (Todoing features,
  Manifest integration, Controlled File Update mechanics).
- Updating the todoing-x repository (separate repo, separate PR #1).
- Archiving existing OpenSpec changes (separate procedure).
