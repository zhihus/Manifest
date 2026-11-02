## Context

Manifest is a documentation-based repository; its rules, plans and context files live under Git. See `docs/plan-1.0.0-context-files-guard.md` (source plan) and `proposal.md` for motivation. Constraints that shape the design:

- The AI harness is ZCode (plugins, MCP, PreToolUse hooks); core must stay harness-independent so other harnesses can add verified adapters later.
- Work happens on Windows (`%LOCALAPPDATA%` available); Git hooks are bypassable and PreToolUse interception covers only supported tools.
- The ZCode plugin's MCP capability is documented but not proven for exact-diff visibility and `ask` behavior in every permission mode — a proof-of-concept gate is required before trust.

## Goals / Non-Goals

**Goals:**
- Core (policy, authorization, Git enforcement) decoupled from any harness.
- One approval = one exact change, enforced at three layers: harness (PreToolUse), Git (pre/post-commit), platform (branch protection + PR).
- Fail closed everywhere; never destroy unrelated work or history.
- Repeatable, non-destructive install with hook chaining.

**Non-Goals:**
- OS-level sandboxing; preventing a determined same-user agent from reading secrets.
- Binary files, symlinks, mode changes, rename/delete, complex merges (MVP deferral).
- Other-harness adapters (Phase 4), mass rollback of changes.

## Decisions

1. **Layered enforcement, Git as backstop.** PreToolUse hooks give early, tool-scoped interception; Git hooks give a harness-independent backstop; hosting-platform branch protection on `Develop` is the final gate. Rationale: each layer alone is bypassable; together they cover the threat model. Alternative: Git hooks only — simpler but no approval UI and weaker tool-level blocking.

2. **MCP approval broker as separate plugin process.** Plugin provides `request_change_approval` over MCP; broker returns a signed receipt only after a confirmed one-time native Allow. Guard validates the receipt before entering `AUTHORIZED`. Rationale: keeps core harness-free; receipts make approvals verifiable outside the harness. Alternative: dedicated approval UI — kept as the fallback if the proof-of-concept gate fails (per spec).

3. **Authorization binding via Git hashes.** Authorization binds repository, branch, base commit, paths, operations, blob hashes and diff hash; pre-commit re-derives hashes from staged content and post-commit re-verifies parent/tree/diff against a durable pre-commit receipt. Rationale: hash comparison is cheap, exact and works for UTF-8 tracked text (MVP scope).

4. **State outside the repo, in `%LOCALAPPDATA%\ContextFilesGuard\`.** Prevents the model from editing authorization state through normal project edits; atomic file writes (write-temp-rename) implement the state machine. Rationale: in-repo state would be trivially tampered with. Trade-off: same-user processes can still reach it — accepted, this is not an OS sandbox.

5. **Managed hook dispatcher with chaining.** Installer sets `core.hooksPath` to a Guard-managed directory; dispatcher scripts invoke existing user hooks first, then Guard hooks. On unexpected existing `core.hooksPath`, installer stops safely. Alternative: overwrite — rejected, silently destroys user setup.

6. **Self-protection via checksums against a trusted reference.** Guard and hook files carry checksums validated against a reference stored outside the managed directory (independently protected, e.g., under the protected policy set). Mismatch ⇒ fail closed.

## Risks / Trade-offs

- [MCP argument visibility not guaranteed in native UI] → Proof-of-concept gate (Phase 2) verifies end-to-end before trust; fallback dedicated approval UI.
- [`--no-verify`, direct FS writes, shell text-processing bypass Git hooks] → PreToolUse blocks known forms; Bash inspection is partial and documented; CI/server-side protection is the stronger assurance.
- [Post-commit mismatch cannot be undone safely] → Report + invalidate + flag for user review; no automatic revert.
- [Hook dispatcher adds friction to every commit] → Fast-path: skip Guard checks when no protected paths are touched.
- [Same-user state tampering] → Documented limitation; checksums and receipts raise the bar but do not eliminate it.

## Migration Plan

Phased per the source plan: 0 specification → 1 core/broker/state/Git hooks/installer → 2 ZCode plugin + approval proof-of-concept → 3 PR workflow + protected `Develop` → 4 self-protection, other-harness adapters, hardening. Rollback: uninstaller restores original hooks configuration from the dispatcher chain record; authorization state is disposable (expiry + fail closed).

## Open Questions

- Exact receipt signing mechanism (HMAC key storage) — deferred to Phase 1 implementation, does not affect specs.
- Which hosting platform's branch-protection settings to codify first (GitHub assumed) — confirm before Phase 3.
