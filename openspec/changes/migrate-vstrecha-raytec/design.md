# Design

## Context

Target project: `C:\\WorkProjects\\vstrecha-raytec`.

This design is based on the read-only audit report supplied on 2026-11-24. The audit found:

- Git branch `master`, HEAD `368c390b03b99165efebc2fa02240c75e1c3a0a6`, clean working tree, 189 local commits, no remotes/upstream, no tags or stashes.
- `.manifest/hooks/` exists and is empty; Project ID, validation script, both hooks, and `core.hooksPath` are absent.
- Existing root `commit-rules.md` is v1.0.0; the current Manifest distribution contains v1.0.1. Other project context files are present and must be preserved.
- `openspec/` is ignored by `.gitignore`; it contains 19 active changes, 6 archived changes, and 3 specs. Thirteen completed changes remain unarchived; six changes are unfinished. Archiving `fix-run-59-defects` currently fails because referenced target specs are missing.
- `.todoing/config.toml` and the Todoing store are absent; the Todoing binary was not found on PATH. No Project ID exists.
- The registry lists the project as active even though installation is incomplete.
- Manifest version references conflict (project `VERSION=0.1.0`, installer distribution 1.1.0, registry 1.0.0); the effective installed version is not established by the audit.

The audit did not compare the local commit graph with a remote, run project tests, inspect every disk location for Todoing, or establish the authoritative Manifest version. Those are not assumed facts.

## Decisions

### D1. Re-audit before mutation

The supplied audit is a baseline, not authorization to modify the project. Before implementation, rerun the relevant read-only checks and compare the current branch, HEAD, working tree, file inventory, ignore rules, OpenSpec inventory, and Manifest installer distribution. Stop if the project has drifted materially from the baseline.

### D2. Preserve Git history and require a remote decision

The 189 local commits are the only known history. The migration MUST NOT rewrite, reset, squash, replace, or force-push that history.

No remote currently exists. The migration MUST present the user with the verified repository/remote options and their consequences. It MUST NOT create a hosting repository, add a remote, push, or configure upstream without separate explicit approval. If the user chooses to remain local-only, the migration may proceed but the final report MUST state that the history has no remote backup/upstream and remote CI/PR workflows are unavailable.

A remote decision is a gate before any operation that would publish or synchronize Git history; it does not authorize publication by itself.

### D3. Treat OpenSpec as existing user data

Before changing `.gitignore`, inspect the exact ignore rule, `git check-ignore -v` results, all tracked/untracked/ignored OpenSpec files, and the contents of the 19 active, 6 archived, and 3 specification entries. Do not assume the audit counts remain current.

Do not use `git add -f openspec/` as a blind migration shortcut. Prepare a proposed tracking set and review exclusions for secrets, generated files, private material, and local-only state. Add OpenSpec to Git only after the user approves the exact scope.

Completed changes are not automatically archived. First inspect each change's delta specs, dependencies, validation result, and archive prerequisites. The known `fix-run-59-defects` blocker must be reported and handled as a separate approved OpenSpec repair; it must not be bypassed by deleting references or fabricating specs.

### D4. Reconcile Manifest installation without overwriting project context

Use the current `manifest-init/dist/` and its verification script as the installer source of truth only after confirming the exact version and artifact contents. The audit's version mismatch must be resolved before installation.

For every existing destination, compare source and target. In particular, do not overwrite `commit-rules.md` v1.0.0 with v1.0.1 automatically. Produce a diff and preserve project-specific rules; install a merged result only after review and approval. Preserve `AGENTS.md`, `llms.txt`, `.llmignore`, README, LICENSE, THIRD-PARTY, tests, pipeline files, and all other project files unless a separately approved change specifies otherwise.

Install hooks only after their contents have been inspected and the user approves enabling them. Set `core.hooksPath=.manifest/hooks` only after the hooks are present and verified.

### D5. Keep Project Identity stable

Create `.manifest/project-id` only if it is absent and after confirming that the project is the intended Manifest connection. Generate a UUIDv4, validate it, and write it atomically. Never replace an existing valid Project ID automatically. If an ID is discovered during re-audit, validate and reuse it; do not generate another.

### D6. Todoing is a local CLI integration

Todoing is installed by the user or through a separately approved installation process. Manifest communicates through `todoing api --json` using stdin/stdout; there is no network API endpoint to configure.

Before creating `.todoing/config.toml` or initializing a store, verify the installed Todoing version and supported API contract, check for existing config/database/legacy Markdown data, and inspect the target paths. Preserve any existing data. Create the configuration without overwrite; initialize only when the store is absent and no legacy migration is required. If Todoing is unavailable, stop at this gate and report the exact prerequisite.

### D7. Separate migration stages and approvals

The migration is staged:

1. Read-only re-audit and baseline report.
2. Decision gates: Git remote strategy, OpenSpec tracking scope, and any conflicting files.
3. Repository hygiene changes explicitly approved by the user.
4. Manifest installation reconciliation and hook activation.
5. Project Identity and Todoing bootstrap.
6. Verification and registry status correction.

Approval of this specification authorizes preparation of the migration design only. It does not authorize any target-project mutation, remote creation, push, hook activation, file replacement, OpenSpec archive, or Todoing installation.

### D8. Registry status reflects verified reality

The registry MUST NOT describe the project as fully active until required Manifest artifacts and enabled hooks pass verification and the selected Todoing/OpenSpec integration state is reported accurately. If the registry schema supports intermediate states, use one. Otherwise retain the existing entry and record the discrepancy until the final verified update is approved.

### D9. Final verification is evidence-based

The final report records exact branch and HEAD, working-tree status, remote/upstream state, Project ID validation, installed Manifest artifact versions, hook path and hook verification, OpenSpec tracking and validation results, Todoing binary/API/store/config status, and unresolved warnings.

Do not run the project's full test suite as an incidental part of migration. Run only checks directly required by the migration; broader tests require a separate decision. A failed or skipped check is reported as such.

## Risks and Mitigations

- **Unbacked-up local history:** no remote exists. Do not publish without approval; explicitly report backup risk.
- **Accidental OpenSpec exposure:** inspect ignore rules and contents before tracking; user approves exact file scope.
- **Loss of project-specific rules:** diff and merge rather than overwrite.
- **Broken or unexpected hooks:** inspect scripts, validate syntax and behavior, then activate only after approval.
- **Identity mismatch:** reuse a valid existing ID; never regenerate automatically.
- **Legacy Todoing data:** inspect before initialization; never overwrite or migrate automatically.
- **False connected status:** update registry only after evidence-based verification.
