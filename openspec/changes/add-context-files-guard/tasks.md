<!-- Naming per openspec-rules.md: FR prefix, kebab-case names, file references in body only. -->
<!-- Waves: group = wave; finish all tasks of a wave, mark [x], stop and report before the next wave. -->

## 1. Core skeleton (Phase 1)

- [ ] 1.1 fr-1.1-create-core-layout: Create the mechanisms context-files-guard directory layout with core, scripts, config subdirectories and installer script; verify structure matches the source plan (`mechanisms/context-files-guard/`, `install.ps1`)
- [ ] 1.2 fr-1.2-implement-policy-loader: Implement the protected-file policy loader that reads the Git-stored policy file listing protected paths, with the policy file itself protected; verify loading a sample policy and that the policy file resolves as protected (`config/protected-files.json`)
- [ ] 1.3 fr-1.3-implement-authorization-state-machine: Implement the authorization state machine with all atomic, terminal and recovery states using atomic file writes in the per-user runtime location; verify state transitions and that no state lands in the repo (unit tests; `%LOCALAPPDATA%\ContextFilesGuard\`)

## 2. Approval broker & receipts (Phase 1)

- [ ] 2.1 fr-2.1-implement-receipt-validation: Implement receipt validation where the Guard accepts only a valid broker receipt bound to repository, branch, base commit, paths, operations, blob hashes and diff hash; verify mismatched base commit or content is rejected (tests)
- [ ] 2.2 fr-2.2-implement-single-use-consumption: Implement single-use consumption where authorization transitions to consumed only after post-commit verification and a failed commit retains it until expiry; verify with scripted commit success and failure flows
- [ ] 2.3 fr-2.3-implement-expiry-and-replay-prevention: Implement expiry, replay and concurrency prevention with a single-writer lock and one-time token; verify second use of the same authorization fails

## 3. Git enforcement (Phase 1)

- [ ] 3.1 fr-3.1-implement-pre-commit-verification: Implement the pre-commit hook verifying staged protected content, blocking extra or mismatched protected changes while preserving unrelated staged work; verify with a staged mixed-commit scenario
- [ ] 3.2 fr-3.2-implement-post-commit-verification: Implement the post-commit hook verifying parent, tree and diff against the durable pre-commit receipt, then consuming authorization, reporting and invalidating on mismatch without auto-revert; verify with a tampered-commit test
- [ ] 3.3 fr-3.3-implement-fail-closed-behavior: Implement fail-closed behavior when the Guard or its state is unavailable; verify protected operations are denied and unrelated work is unaffected
- [ ] 3.4 fr-3.4-implement-hooks-path-and-no-verify-controls: Implement the effective hooks-path value check and known-form no-verify detection; verify a redirected hooks path fails closed (`core.hooksPath`, `--no-verify`)

## 4. Installer (Phase 1)

- [ ] 4.1 fr-4.1-implement-installer-with-hook-chaining: Implement the installer with a managed hooks dispatcher that chains existing hooks and never silently replaces the hooks path; verify reinstall and pre-existing hooks path scenarios (`install.ps1`)
- [ ] 4.2 fr-4.2-implement-safe-failure-and-worktree-support: Implement safe failure on unsupported layouts, update support and worktree handling with explicit enable or clear warning; verify the worktree checkout scenario
- [ ] 4.3 fr-4.3-implement-uninstaller: Implement the uninstaller restoring the original hooks configuration from the dispatcher chain record; verify the install-uninstall round trip returns the original config

## 5. ZCode plugin & proof-of-concept (Phase 2)

- [ ] 5.1 fr-5.1-create-zcode-plugin-skeleton: Create the ZCode plugin directory with plugin manifest, hooks definition, MCP configuration and broker module; verify the plugin loads when explicitly enabled (`plugins/context-files-guard-zcode/`)
- [ ] 5.2 fr-5.2-implement-approval-tool: Implement the MCP approval tool returning a receipt only after a confirmed one-time allow or reject decision; verify reject and timeout produce no receipt (`request_change_approval`)
- [ ] 5.3 fr-5.3-configure-pretooluse-hooks: Configure PreToolUse hooks forcing the approval tool to ask, permitting only authorization-matching protected operations, and denying unsupported or ambiguous writes without consuming authorization; verify each path
- [ ] 5.4 fr-5.4-run-approval-proof-of-concept: Run the end-to-end proof-of-concept confirming the exact diff is visible in the native UI and ask behavior holds across permission modes; if insufficient, switch to the dedicated approval UI fallback and record the decision

## 6. PR workflow & branch protection (Phase 3)

- [ ] 6.1 fr-6.1-implement-branch-rules: Implement branch rules blocking commits and pushes to the integration branch and task-branch creation from it; verify a commit on the integration branch is rejected (`Develop`)
- [ ] 6.2 fr-6.2-apply-platform-branch-protection: Document and apply hosting-platform protection for the integration branch requiring PR, approval and checks with direct and force pushes restricted; verify direct push is rejected platform-side
- [ ] 6.3 fr-6.3-verify-separate-approval-gates: Verify separate gates where a Guard-approved change merges only via an approved PR and a changed PR diff requires renewed approval

## 7. Self-protection & hardening (Phase 4)

- [ ] 7.1 fr-7.1-implement-checksum-self-protection: Implement checksums of Guard and hook files validated against an independently protected trusted reference; verify tampering fails closed
- [ ] 7.2 fr-7.2-verify-mvp-scope-boundaries: Verify MVP scope boundaries covering binary and untracked file denial, unrelated work preservation, and no mass rollback with only explicit targeted reversal

## 8. Acceptance pass

- [ ] 8.1 fr-8.1-run-acceptance-checklist: Execute the acceptance checklist from the source plan end-to-end covering visible independent approval, model cannot mint authorization, scoped authorization consumed only after matching commit, commits stay on the task branch, only approved PR merges to the integration branch, failures fail closed, installer preserves settings
- [ ] 8.2 fr-8.2-validate-and-review-artifacts: Run strict OpenSpec validation and an archive-ready review of all artifacts
