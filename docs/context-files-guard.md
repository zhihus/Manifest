# Context Files Guard — Pre-Implementation Specification
Draft; design only.

## 1. Purpose & Structure
Protect user-designated files from unsanctioned AI changes. User authorizes; model performs; Guard enforces. Work occurs on a task branch; integration into `Develop` requires an approved PR.

```text
mechanisms/context-files-guard/
  core/       — policy, authorization, Git dispatcher
  scripts/    — state, verification, recovery
  config/     — protected-files.json (Git)
  install.ps1
plugins/context-files-guard-zcode/
  .zcode-plugin/plugin.json
  hooks/hooks.json
  .mcp.json
  mcp/        — approval broker
```
Core is Harness-independent; adapters are separate plugins. ZCode hooks ship in an explicitly enabled plugin, not project config.

## 2. Responsibilities
- **Model:** proposes exact diff/reason; applies, verifies, stages and commits approved work on task branch; opens/updates PR. Cannot issue authorization, approve PR or merge to `Develop`.
- **User:** approves protected-file edits in ZCode and reviews/approves PR.
- **ZCode plugin:** MCP approval broker + PreToolUse hooks; connects native permission UI to Guard.
- **Guard:** policy, authorization state and validation.
- **Git hooks:** validate staged changes/commits; branch rules protect integration.
- **Installer:** repeatable, non-destructive core install; plugin enabled separately.

## 3. ZCode Approval Bridge
Plugin provides MCP tool `request_change_approval`. Model submits repo, branch, paths, exact diff and reason. PreToolUse forces this tool to `ask`; native UI must show the exact change. User selects one-time Allow or Reject. Never use ordinary chat questions, model-written approval text or Always Allow.

Broker issues a receipt only after confirmed tool execution; Guard validates it. Rejection, timeout or ambiguous prompt = no authorization. Other Harnesses need verified adapters.

**Proof-of-concept gate:** docs confirm plugin MCP servers, PreToolUse `allow/ask/deny`, and native UI showing tool actions. They do not guarantee full MCP argument visibility or `ask` behavior in every permission mode. Verify end-to-end first. If insufficient, use a dedicated approval UI; chat text is never consent.

## 4. Authorized Change Lifecycle
One approval covers one exact change.
1. Model prepares diff, repository, task branch, base commit and paths.
2. Broker displays actual diff/summary and obtains direct approval.
3. Guard issues short-lived, single-use authorization bound to repository, branch, base commit, paths, operations, blob hashes and diff hash.
4. PreToolUse permits only matching protected-file operations; deny unsupported/ambiguous writes. Do not consume authorization.
5. Model stages change. Pre-commit verifies staged protected content; extra/mismatched protected changes block commit. Preserve unrelated staged work.
6. Model commits on task branch. Post-commit verifies parent/tree/diff against durable pre-commit receipt, then consumes authorization.
7. Failed commit retains authorization until expiry. Ambiguous/interrupted state blocks protected operations pending recovery; post-commit cannot undo a completed commit.

Git-only mode may authorize an existing diff only after displaying that exact diff; same checks apply.

## 5. Authorization & State
Approval originates from native user interaction, not model claims. Atomic states:
`PROPOSED → APPROVAL_PENDING → APPROVED → AUTHORIZED → COMMIT_PENDING → CONSUMED`
Terminal: `REJECTED`, `EXPIRED`, `INVALIDATED`; recovery: `RECOVERY_REQUIRED`. Prevent replay/concurrency; base/content change requires new approval. Runtime state: `%LOCALAPPDATA%\ContextFilesGuard\`; project policy under Git. Same-user secrets do not stop a determined agent; this is not an OS sandbox.

## 6. Git, PR & Develop
- Never work directly on `Develop`. Create a task branch from current `Develop`; all task commits stay there.
- Push branch and open PR to `Develop`; model may update it and address feedback.
- User reviews PR diff and approves. Merge only through hosting platform after approval/checks; no direct push or local copy into `Develop`.
- Protect `Develop`: require PR, approval and checks; restrict direct/force pushes/bypass. Changed PR diff requires renewed approval.
- Guard approval authorizes editing a protected file; PR approval authorizes integrating the branch. Separate gates.
- Rejected/closed PR stays isolated; no automatic rollback.

## 7. Git Scope & Bypass
MVP: tracked UTF-8 text files; compare Git blob bytes/hashes. Defer binary, symlink, mode, rename/delete and complex merges. Never discard unrelated work.

| Vector | Control |
|---|---|
| `--no-verify` | ZCode PreToolUse blocks known forms; not universal |
| `core.hooksPath` | Check effective value; reject unexpected |
| Direct FS write | ZCode hooks cover supported tools only |
| `apply`/`checkout`/`sed` | Partial Bash inspection |
| Guard/hook edit | Checksums; trusted reference required |

Git hooks are bypassable; PreToolUse is not OS isolation. Use CI/server for stronger assurance.

## 8. Installation, Risks & Phases
Preserve existing hooks/settings via managed dispatcher/chaining; never silently replace `core.hooksPath`. Stop safely on unsupported layouts; test reinstall, updates and Worktrees. Checksums need an independently protected reference. Fail closed if Guard, broker, state, hooks or approval UI are unavailable. No mass rollback; only explicit request for a specific safely reversible operation.

**Phases:** 0 specification; 1 core/broker/state/Git/installer; 2 ZCode plugin + approval proof-of-concept; 3 PR workflow/protected `Develop`; 4 self-protection, other Harness adapters and hardening.

**Acceptance:** visible independent approval; model cannot mint authorization; scoped authorization consumed only after matching commit; unrelated work preserved; commits stay on task branch; only approved PR merges to `Develop`; failures fail closed; installer preserves settings.