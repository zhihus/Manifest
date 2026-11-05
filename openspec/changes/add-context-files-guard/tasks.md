<!-- Naming per openspec-rules.md: FR prefix, numbering FR N.M, title in the name, file references in the body only. -->
<!-- Waves: one group = one wave; finish all tasks of a wave, mark [x], stop and report before the next wave. -->
<!-- One subagent run = one task (FR). Verification is mechanical (structure checks, scripted scenarios, greps), not an opinion. -->

## 1. Core skeleton (Wave 1)

- [ ] FR 1.1 Create core layout — Create the directory layout for the Guard core: `mechanisms/context-files-guard/core/` (policy, authorization, Git dispatcher), `mechanisms/context-files-guard/scripts/` (state, verification, recovery), `mechanisms/context-files-guard/config/` and the installer `mechanisms/context-files-guard/install.ps1`. The layout must match the source structure: core is harness-independent; ZCode hooks ship in a separate plugin, not project config.
  - Stop criterion: the four directories and `install.ps1` exist; `git status` shows them staged on the task branch.

- [ ] FR 1.2 Implement policy loader — Implement the protected-file policy loader in `mechanisms/context-files-guard/core/`: it reads `mechanisms/context-files-guard/config/protected-files.json` (the Git-stored policy listing protected paths) and resolves whether a given path is protected. The policy file itself must resolve as protected.
  - Stop criterion: loading a sample `protected-files.json` succeeds; a query for a listed path returns "protected"; a query for the policy file itself returns "protected"; a query for an unlisted path returns "not protected".

- [ ] FR 1.3 Implement authorization state machine — Implement the authorization state machine in `mechanisms/context-files-guard/core/` with all states: `PROPOSED → APPROVAL_PENDING → APPROVED → AUTHORIZED → COMMIT_PENDING → CONSUMED`, terminal `REJECTED`/`EXPIRED`/`INVALIDATED`, recovery `RECOVERY_REQUIRED`. All state files are written atomically (write-temp-rename) to the per-user runtime location `%LOCALAPPDATA%\ContextFilesGuard\` — never inside the repository.
  - Stop criterion: scripted transitions exercise every legal transition and the terminal states; a state file never appears in `git status`; each write is atomic (no partial file observed by a concurrent reader).

## 2. Approval broker & receipts (Wave 2)

- [ ] FR 2.1 Implement receipt validation — Implement receipt validation in the Guard core: an authorization is accepted only with a valid broker receipt bound to repository, branch, base commit, paths, operations, blob hashes and diff hash.
  - Stop criterion: scripted scenarios where a receipt with a mismatched base commit is rejected and one with mismatched content hashes is rejected; a fully matching receipt is accepted.

- [ ] FR 2.2 Implement single-use consumption — Implement single-use consumption: the authorization transitions to `CONSUMED` only after post-commit verification; a failed commit retains the authorization until expiry.
  - Stop criterion: scripted commit-success flow ends with state `CONSUMED`; scripted commit-failure flow ends with the authorization still active (not consumed) before expiry.

- [ ] FR 2.3 Implement expiry and replay prevention — Implement expiry, replay and concurrency prevention in `mechanisms/context-files-guard/scripts/`: single-writer lock and one-time token; a base or content change requires a new approval.
  - Stop criterion: a second use of the same authorization fails; two concurrent consumers cannot both succeed (one blocks or fails); an expired authorization is rejected.

## 3. Git enforcement (Wave 3)

- [ ] FR 3.1 Implement pre-commit verification — Implement the pre-commit hook in `mechanisms/context-files-guard/scripts/`: verify staged protected content against the authorization; block the commit on extra or mismatched protected changes while preserving unrelated staged work.
  - Stop criterion: a scripted mixed-commit scenario (protected + unrelated staged files) blocks on protected mismatch and leaves the unrelated staged files intact in the index.

- [ ] FR 3.2 Implement post-commit verification — Implement the post-commit hook: verify parent, tree and diff against the durable pre-commit receipt, then consume the authorization; on mismatch report, invalidate (no auto-revert).
  - Stop criterion: a scripted commit matching the receipt passes and consumes the authorization; a scripted tampered commit is reported and the authorization is invalidated without any automatic revert.

- [ ] FR 3.3 Implement fail-closed behavior — Implement fail-closed behavior: when the Guard, its state, the broker or the approval UI is unavailable, protected operations are denied; unrelated work is unaffected.
  - Stop criterion: scripted scenarios with the state directory unreadable and with the broker absent both deny a protected operation and allow a non-protected operation.

- [ ] FR 3.4 Implement hooks-path and no-verify controls — Implement the effective `core.hooksPath` value check (reject unexpected values) and known-form `--no-verify` detection in the PreToolUse layer.
  - Stop criterion: a scripted run with a redirected `core.hooksPath` fails closed; a scripted `git commit --no-verify` on a protected operation is blocked at the PreToolUse layer.

## 4. Installer (Wave 4)

- [ ] FR 4.1 Implement installer with hook chaining — Implement `mechanisms/context-files-guard/install.ps1` as a repeatable, non-destructive installer: set `core.hooksPath` to a Guard-managed dispatcher directory; the dispatcher invokes existing user hooks first, then Guard hooks; never silently replace an existing hooks path (stop safely instead).
  - Stop criterion: an install → reinstall round trip keeps pre-existing hooks executing (dispatcher chain record shows them); an install onto an unsupported existing `core.hooksPath` aborts with no configuration change.

- [ ] FR 4.2 Implement safe failure and worktree support — Extend the installer: explicit enable or clear warning for worktree checkouts; safe failure on unsupported layouts; update support for an existing managed install.
  - Stop criterion: a scripted worktree scenario either enables the Guard explicitly or warns clearly (never silently skips); an unsupported layout aborts without modifying Git configuration.

- [ ] FR 4.3 Implement uninstaller — Implement the uninstaller restoring the original hooks configuration from the dispatcher chain record.
  - Stop criterion: an install → uninstall round trip returns `core.hooksPath` (and existing hooks) to the pre-install state, verified by comparing the configuration before install and after uninstall.

## 5. ZCode plugin & proof-of-concept (Wave 5)

- [ ] FR 5.1 Create ZCode plugin skeleton — Create the plugin at `plugins/context-files-guard-zcode/`: `.zcode-plugin/plugin.json`, `hooks/hooks.json`, `.mcp.json` and the MCP broker module under `plugins/context-files-guard-zcode/mcp/`. The plugin is enabled explicitly, not via project config.
  - Stop criterion: ZCode loads the plugin when explicitly enabled (plugin appears in the session tool list); the PreToolUse hooks and the MCP server are registered by the plugin.

- [ ] FR 5.2 Implement approval tool — Implement the MCP tool `request_change_approval`: the model submits repository, branch, paths, exact diff and reason; the broker returns a receipt only after a confirmed one-time Allow in the native permission UI. Reject and timeout produce no receipt.
  - Stop criterion: scripted broker runs — confirmed Allow returns a receipt; Reject returns none; timeout returns none.

- [ ] FR 5.3 Configure PreToolUse hooks — Configure `plugins/context-files-guard-zcode/hooks/hooks.json`: the approval tool is forced to `ask`; only authorization-matching protected operations are permitted; unsupported or ambiguous writes are denied without consuming the authorization.
  - Stop criterion: each path is exercised in a scripted run — protected matching write proceeds; protected non-matching write is denied; ambiguous write is denied with the authorization still unconsumed.

- [ ] FR 5.4 Run approval proof-of-concept — Run the end-to-end proof-of-concept gate: confirm the exact diff is visible in the native ZCode UI and `ask` behavior holds across permission modes. If insufficient, switch to the dedicated approval UI fallback and record the decision in `design.md`.
  - Stop criterion: a written proof-of-concept outcome exists in the change folder (pass, or fallback decision recorded) covering diff visibility and `ask` behavior per permission mode.

## 6. PR workflow & branch protection (Wave 6)

- [ ] FR 6.1 Implement branch rules — Implement branch rules in the Guard scripts: commits and pushes to the integration branch `Develop` are blocked; task branches are created from current `Develop`; all task commits stay on the task branch.
  - Stop criterion: a scripted commit attempt on `Develop` is rejected; a scripted push to `Develop` is rejected.

- [ ] FR 6.2 Apply platform branch protection — Document and apply hosting-platform protection for `Develop` (GitHub assumed): require PR, approval and checks; restrict direct and force pushes.
  - Stop criterion: platform settings show the protection rules; a scripted direct push to `Develop` is rejected platform-side.

- [ ] FR 6.3 Verify separate approval gates — Verify that Guard approval and PR approval are separate gates: a Guard-approved change merges only via an approved PR; a changed PR diff requires renewed approval.
  - Stop criterion: scripted scenarios — a merge without PR approval is rejected; a modified PR diff is rejected until a new approval is captured.

## 7. Self-protection & hardening (Wave 7)

- [ ] FR 7.1 Implement checksum self-protection — Implement checksums of Guard and hook files validated against an independently protected trusted reference (outside the managed directory, e.g. under the protected policy set); mismatch fails closed.
  - Stop criterion: a scripted tamper of a Guard file is detected and protected operations are denied; an untampered install passes the checksum check.

- [ ] FR 7.2 Verify MVP scope boundaries — Verify the MVP scope: binary and untracked file operations are denied with a clear message; unrelated work is never discarded; no mass rollback — only explicit, targeted, safely reversible reversal on explicit request.
  - Stop criterion: scripted scenarios — a binary protected-file edit is denied with a clear message; an untracked protected-path edit is denied; a rejection leaves unrelated staged/committed work intact.

## 8. Acceptance pass (Wave 8)

- [ ] FR 8.1 Run acceptance checklist — Execute the acceptance checklist end-to-end and record each outcome:
  1. Approval is visible and independent (native UI, one-time decision, not chat text).
  2. The model cannot mint authorization (no path from model actions to a valid receipt).
  3. Scoped authorization is consumed only after a matching commit.
  4. Unrelated work is preserved on every rejection path.
  5. Commits stay on the task branch (`Develop` direct commit is rejected).
  6. Only an approved PR merges to `Develop`.
  7. Failures fail closed (Guard, broker, state, hooks, UI unavailable → protected operations denied).
  8. Installer preserves existing settings (dispatcher chaining, uninstall round trip).
  - Stop criterion: eight outcomes recorded in the change folder, each with the scenario run and pass/fail.

- [ ] FR 8.2 Validate and review artifacts — Run strict OpenSpec validation over the change and an archive-ready review of all artifacts (proposal.md, design.md, specs, tasks.md).
  - Stop criterion: `openspec validate add-context-files-guard` reports valid; every artifact has a recorded review outcome.
