# Design

## Context

The parser (`scripts/structure-parser.sh`) is a derivative of the
rules source (`workflow/file-structure-rules.ru.md`). See proposal.md
— Why. Baseline for "changed" is HEAD: rules and parser change in one
commit, so HEAD is always consistent.

## Goals / Non-Goals

**Goals:**

- One script (`scripts/verify.sh`) with all sync-check logic,
  runnable manually and from a hook.
- Bilingual output, matching the parser's message style.

**Non-Goals:**

- No delivery of verify.sh into connected projects (manifest-init
  `dist/`) — separate change.
- No parser-contract version markers — the "changed against HEAD"
  comparison is sufficient while rules and parser commit together.

## Decisions

- **Wrapper hook, logic in verify.sh.** The hook is ~5 lines
  (resolve root, run verify.sh, exit with its code). One source of
  messages for both manual and hook runs; the hook file stays
  trivially readable.
- **HEAD as baseline via `git diff HEAD --name-only`.** No version
  markers or hashes: per commit rules the rules file and the parser
  change in one commit, so HEAD is always the "version before the
  change". Parser-only changes are bug fixes — allowed, but verified
  by the same test suite.
- **Fixture generated on the fly** (`mktemp -d`, removed on exit):
  temp/ is cleaned periodically, the check must not depend on files
  left there.
- **References glob `workflow/*.ru.md` + `workflow/*.en.md`:**
  14 known-clean files test the "over-reporting" direction; the
  fixture tests the "under-reporting" direction.

## Risks / Trade-offs

- [Manual-only runs can be forgotten] → the pre-commit hook guarantees
  the run; manual runs remain useful before committing.
- [Legitimate rules changes that make a reference stale] → verify.sh
  blocks the commit; the human/model reads the violation list and
  updates the reference in the same commit.

## Migration Plan

Additive files; activation is one local git config command. Rollback:
delete the two files and unset `core.hooksPath`.

## Open Questions

None — behavior agreed in `docs/plans/verify-script-plan.en.md`.
