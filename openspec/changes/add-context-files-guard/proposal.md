## Why

User-designated files can be changed by an AI agent without explicit sanction: the model edits, stages and commits freely, and nothing enforces a separate, visible user approval for those specific files. The Manifest project keeps its rules, plans and context files under Git and needs a mechanism that makes protected-file edits impossible without an explicit, independently captured approval, while keeping normal work on task branches and integrating into `Develop` only through an approved PR.

## What Changes

- Introduce **Context Files Guard**: a Git-based mechanism (policy, authorization state, Git dispatcher/hooks) that protects user-designated files from unsanctioned AI changes.
- Add a protected-file policy file `config/protected-files.json` stored under Git.
- Add an authorization lifecycle with atomic states (`PROPOSED → APPROVAL_PENDING → APPROVED → AUTHORIZED → COMMIT_PENDING → CONSUMED`, terminal `REJECTED`/`EXPIRED`/`INVALIDATED`, recovery `RECOVERY_REQUIRED`), single-use, short-lived, bound to repository, branch, base commit, paths, operations, blob hashes and diff hash.
- Add a ZCode plugin with an MCP approval broker (`request_change_approval`) and PreToolUse hooks that route every protected-file operation through the native permission UI; chat text, model-written approval text and "Always Allow" are never consent.
- Add pre-commit/post-commit Git hook verification: staged protected content is checked before commit; authorization is consumed only after post-commit verification against a durable pre-commit receipt.
- Add a repeatable, non-destructive installer that preserves existing hooks/settings via managed dispatcher/chaining and fails closed on unsupported layouts.
- Enforce the branch/PR workflow: never commit to `Develop` directly; task branches plus PR with user review; Guard approval and PR approval are separate gates.

## Capabilities

### New Capabilities
- `context-files-guard/policy`: What files are protected, how the policy is configured and versioned, and what counts as a protected operation (scope: tracked UTF-8 text files; Git blob byte/hash comparison).
- `context-files-guard/authorization`: Approval capture, authorization issuance, state machine, single-use binding, expiry, replay/concurrency prevention, receipt validation, recovery.
- `context-files-guard/zcode-approval-bridge`: The MCP approval broker and PreToolUse hook behavior that connect the native ZCode permission UI to the Guard, including the proof-of-concept gate for MCP argument visibility and `ask` behavior.
- `context-files-guard/git-enforcement`: Pre-commit/post-commit verification, commit blocking, branch rules for `Develop`, bypass vectors and their partial controls (`--no-verify`, `core.hooksPath`, direct FS writes, Guard self-protection).
- `context-files-guard/installation`: Installer behavior — non-destructive install/reinstall/update, hook chaining, worktrees, fail-closed conditions.
- `context-files-guard/pr-workflow`: Task-branch/PR integration rules for `Develop`, separation of Guard approval from PR approval, merge restrictions.

### Modified Capabilities
<!-- None: this change introduces a new mechanism; no existing capability requirements change. -->

## Impact

- **New code**: `mechanisms/context-files-guard/` (core, scripts, config, installer) and `plugins/context-files-guard-zcode/` (plugin manifest, hooks, MCP broker).
- **Harness**: ZCode plugin must be explicitly enabled; MCP server and PreToolUse hooks registered by the plugin, not project config.
- **Git**: managed dispatcher at `core.hooksPath` (existing hooks preserved via chaining); branch protection on `Develop` configured at the hosting platform.
- **Runtime state**: `%LOCALAPPDATA%\ContextFilesGuard\` (outside Git, same-user protected — documented as not an OS sandbox).
- **Out of scope (MVP)**: binary files, symlinks, mode changes, rename/delete, complex merges; other harnesses (adapters deferred to a later phase).
