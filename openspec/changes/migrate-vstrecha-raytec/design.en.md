# Design

## Context

Target project: `C:\WorkProjects\vstrecha-raytec`. This design is based on the read-only audit supplied on 2026-11-24:

- Git branch `master`, HEAD `368c390b03b99165efebc2fa02240c75e1c3a0a6`, clean worktree, 189 local commits, no remote/upstream.
- Manifest: `.manifest/hooks/` exists but is empty; Project ID, validation script, and both hooks are absent; `core.hooksPath` is unset. Root `commit-rules.md` is v1.0.0 while the Manifest distribution contains v1.0.1.
- OpenSpec is excluded from Git by `.gitignore`; the audit found 19 active changes, 6 archived changes, and 3 specs. Thirteen completed changes remain unarchived and six are unfinished. Archiving `fix-run-59-defects` is blocked by missing target specs.
- Todoing config/store are absent and the binary was not found on PATH.
- The registry says active although installation is incomplete.
- Manifest version references conflict: project `VERSION=0.1.0`, installer distribution 1.1.0, registry 1.0.0.

The audit did not compare local history with a remote, run project tests, search the entire disk for Todoing, or establish the authoritative Manifest version. These remain unverified.

## Decisions

### D1. Re-audit before mutation

The supplied audit is a baseline, not authorization to modify the project. Recheck Git, files, ignore rules, OpenSpec, installer artifacts, and Todoing before implementation. Stop and revise the plan if material drift is found.

### D2. Preserve Git history; require a separate remote decision

Preserve the existing commit graph. Do not rewrite history, reset, squash, force-push, or change branches without approval.

No remote/upstream exists. The user must choose the backup and synchronization strategy before publication. Do not create a hosting repository, add a remote, configure upstream, or push without separate explicit approval. A local-only choice does not block migration, but the final report must state that there is no remote backup and remote CI/PR workflows are unavailable.

### D3. Treat OpenSpec as existing user data

Before changing `.gitignore`, inspect exact ignore rules, `git check-ignore -v`, and all tracked/untracked/ignored OpenSpec files, changes, and specs. Prepare an exact Git tracking proposal and exclusions; inspect for secrets, generated files, and local-only data.

Do not blindly run `git add -f openspec/`. Add OpenSpec to Git only after the user approves the exact file scope.

Do not automatically archive completed changes. Check each change's delta specs, dependencies, and archive prerequisites. Handle the known `fix-run-59-defects` blocker as a separate approved repair; do not bypass it by deleting references or fabricating specs.

### D4. Reconcile Manifest artifacts without overwriting

Confirm the authoritative Manifest version and inspect installer distribution, validation script, and hooks before installation. Resolve the version mismatch found by the audit.

Compare every proposed artifact with its destination. In particular, do not replace `commit-rules.md` v1.0.0 with v1.0.1 automatically: produce a diff, preserve project-specific rules, and obtain approval for the result. Preserve `AGENTS.md`, `llms.txt`, `.llmignore`, README, LICENSE, THIRD-PARTY, tests, pipeline, and all other project files by default.

Install and activate hooks only after inspection and separate user approval. Set `core.hooksPath=.manifest/hooks` only after both hooks are installed and verified.

### D5. Keep Project Identity stable

Create `.manifest/project-id` only after confirming the target project and only if the file is absent. Use UUIDv4 and atomic creation. Reuse an existing valid ID; never replace it automatically.

### D6. Use Todoing through its local CLI

Todoing is installed by the user or through a separately approved procedure. Manifest invokes its JSON API through local `todoing api --json` (stdin/stdout); there is no network API endpoint.

Before bootstrap, verify the binary/version and API contract, and inspect config/database/legacy Markdown data. Never overwrite existing data. Create `.todoing/config.toml` without overwrite and initialize the store only if no store or legacy data exists. If Todoing is unavailable, stop and report the exact prerequisite.

### D7. Stages and approval boundaries

1. Read-only re-audit.
2. User decisions: Git remote, OpenSpec tracking scope, and file conflicts.
3. Approved Git hygiene and OpenSpec tracking changes.
4. Manifest reconciliation/installation; separate approval to activate hooks.
5. Project Identity and Todoing bootstrap.
6. Verification and registry reconciliation.

Approval of this specification authorizes preparation of the plan only. It does not authorize target-project changes, remote creation, push, hook activation, file replacement, OpenSpec archive, or Todoing installation.

### D8. Registry status

Do not treat the project as fully active until required Manifest artifacts and hooks pass verification and OpenSpec/Todoing state is accurately reported. Use an intermediate registry status if supported. Otherwise retain the entry until final verification and separate approval.

### D9. Evidence-based final verification

The final report records branch/HEAD/status, remote/upstream, history preservation, Project ID, Manifest artifact versions, hooks and `core.hooksPath`, OpenSpec tracking/validation, Todoing binary/API/config/store, and unresolved blockers.

Run only migration-specific checks. Do not run the full application test suite without a separate decision. Report every skipped or failed check explicitly.

## Risks

- No remote backup exists for local Git history; user decision required.
- OpenSpec may contain local-only or sensitive data; inspect every path before tracking.
- Diff and approval prevent loss of project-specific rules.
- Verify hooks before activation.
- Never replace Project ID or bootstrap over existing Todoing data.
- Update registry only from verification evidence.
