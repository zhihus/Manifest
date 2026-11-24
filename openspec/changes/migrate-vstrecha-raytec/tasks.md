# Tasks: migrate-vstrecha-raytec

> This change specifies a controlled migration. It does not authorize execution in the target repository. Each target-project mutation requires a separate user approval at the applicable gate.

## 1. Re-audit

- [ ] fr-1.1-refresh-read-only-baseline
  Re-run read-only checks in `C:\WorkProjects\vstrecha-raytec`: Git branch/HEAD/status/log/remotes, project file inventory, `.gitignore` and `.llmignore`, Manifest installation artifacts, OpenSpec inventory, Todoing paths and binary availability. Compare results with the 2026-11-24 audit and record drift.
  Stop: a timestamped baseline report lists verified facts, unknowns, and all material differences; no target file is changed.

## 2. Git history and remote decision

- [ ] fr-2.1-assess-git-history-and-remote-options
  Document the 189-commit local history, current branch/HEAD, absence or presence of remote/upstream after re-audit, and viable backup/hosting strategies. Do not create a repository, add a remote, push, change branches, or rewrite history.
  Stop: options and consequences are presented to the user and the chosen strategy is recorded; no publication action is performed.

## 3. OpenSpec tracking decision

- [ ] fr-3.1-inventory-openspec-and-ignore-rules
  Inspect exact ignore rules and their source locations; enumerate all tracked, untracked, and ignored files under `openspec/`; inspect all active/archived changes and specs, including dependencies and validation status. Identify sensitive/generated/local-only files.
  Stop: a complete proposed tracking manifest and change-by-change status report exist; no ignore rule or OpenSpec file is modified.

- [ ] fr-3.2-approve-openspec-tracking-scope
  Present the exact proposed OpenSpec files and exclusions to the user. Do not stage or force-add files before approval.
  Stop: user decision and approved path scope are recorded; no Git index or working-tree mutation is performed.

- [ ] fr-3.3-assess-completed-change-archive-readiness
  For each completed unarchived change, verify delta-spec targets, dependencies, and OpenSpec archive prerequisites. Report the `fix-run-59-defects` missing-spec blocker separately. Do not archive or repair changes in this task.
  Stop: every completed change has a documented archive-ready / blocked / needs-review result; no change is archived.

## 4. Manifest artifact reconciliation

- [ ] fr-4.1-confirm-installer-version-and-artifacts
  Inspect current Manifest installer version, distributed files, `verify.sh`, and hook contents. Resolve the audit's version mismatch using authoritative repository metadata; do not infer the installed version from the registry alone.
  Stop: the source version and exact install artifact checksums/paths are documented.

- [ ] fr-4.2-prepare-non-destructive-file-reconciliation
  Compare each proposed Manifest artifact with existing project files. Produce a conflict report and a reviewed merge proposal for `commit-rules.md` v1.0.0 versus distributed v1.0.1. Preserve all existing context and project files by default.
  Stop: every destination is classified as create / identical / merge-required / conflict / omit; no target file is written.

- [ ] fr-4.3-install-and-verify-manifest-hooks
  First present the exact files to create or change, their diffs, hook behavior, and the proposed `core.hooksPath` change; obtain a separate explicit user approval for this stage. Only then install the approved hook files and validation script, validate their syntax and behavior, and configure `core.hooksPath=.manifest/hooks`. Do not treat approval of another migration stage as authorization for this stage, and do not activate hooks before the approved files pass verification.
  Stop: both hooks and validation script pass their checks, `core.hooksPath` points to the verified directory, and the verification output is recorded.

## 5. Project Identity and Todoing bootstrap

- [ ] fr-5.1-create-or-validate-project-id
  Re-audit the target path and determine whether a valid Project ID already exists. If creation or repair is required, present the exact operation and target path and obtain separate explicit user approval for this stage. Then reuse an existing valid Project ID or create a UUIDv4 in `.manifest/project-id` using atomic creation. Never overwrite an existing value. Approval of hook installation or another stage does not authorize this write.
  Stop: exactly one valid stable Project ID is present and its value is verified against the Todoing validation contract.

- [ ] fr-5.2-verify-todoing-prerequisites
  Check Todoing binary availability/version, supported API v1 operations, existing `.todoing/` contents, config, database, and legacy Markdown data. Do not install or upgrade Todoing in this task.
  Stop: prerequisites are classified as ready / user action required / blocked, with evidence; no Todoing data is created or changed.

- [ ] fr-5.3-bootstrap-todoing-without-overwrite
  After successful prerequisite checks, present the exact config content, store initialization operation, and affected paths; obtain separate explicit user approval for this stage. Only then create `.todoing/config.toml` without overwriting existing content and initialize the store only when absent and no legacy migration is required. Use the local CLI JSON API; do not configure a network endpoint. Approval of Project ID creation or another stage does not authorize this bootstrap.
  Stop: config and store are initialized or a precise non-destructive blocker is reported; existing data remains unchanged.

## 6. Final verification and registry

- [ ] fr-6.1-run-migration-specific-verification
  Verify Git state/history preservation, approved OpenSpec tracking scope, Manifest files and hooks, Project ID, Todoing config/store/API status, and the final project structure. Run only migration-specific checks; do not run the full application test suite.
  Stop: an evidence-based report records pass/fail/skipped for each check and lists remaining risks.

- [ ] fr-6.2-reconcile-connected-project-registry
  After all required checks pass, present the exact registry diff and obtain separate explicit user approval for this registry update. Only then change the connected-project registry status/version to match verified reality. If any required integration remains blocked, do not mark the project fully active.
  Stop: registry state matches the verification report, or the discrepancy is explicitly retained and reported.
