# Tasks: add-manifest-init-mvp

## Wave 1 — manifest-init core

- [ ] FR 1.1 init-entrypoint-skeleton

Create `scripts/manifest-init.sh` (Bash, `set -euo pipefail`). The
script accepts two arguments: `--project <dir>` (target project root,
default `.`) and `--templates <dir>` (Manifest template source, e.g.
`<manifest-repo>/docs/templates`; mandatory). Behavior in this task:
1. Parse arguments; unknown usage exits 2 with a usage line.
2. Preflight placeholder function `preflight()` that must be called
   before any write (implemented fully in FR 2.1; here it only checks
   that `$TEMPLATES` exists and is readable and that `$PROJECT/.manifest`
   does not exist).
3. Create `.manifest/` in the project root; write
   `.manifest/manifest.yaml` with exactly three lines:
   `project_name=<asked>` (see FR 1.2; here default
   `project_name=unnamed`), `tracks=none|code|documentation|mixed`,
   `created=<YYYY-MM-DD>`.
4. Write `.manifest/manifest.yaml.checksum` containing the
   `sha256sum` output of `manifest.yaml`.
5. Exit 0 and print `INIT OK`.
Stop criterion: running the script in a temp project with both flags
creates `.manifest/manifest.yaml` and its checksum file; second run
exits non-zero with message `REINIT_REFUSED` and does not modify the
files; verify by `sha256sum` comparison.
Maps to scenarios: Config location; Re-run against an initialized
project; Modified configuration detected; Protection against accidental
configuration overwrite.

- [ ] FR 1.2 interview-and-report

Extend `scripts/manifest-init.sh`. Implement the interview: analyze
the target project (presence of code files by extension and of a
`docs/` directory) to propose a `tracks` value, ask the user to
confirm or change project name and tracks, accept input non-
interactively when `--project-name` and `--tracks` flags are given
(flags are the MVP contract; interactive prompts only when the flags
are absent). Persist the confirmed values into
`.manifest/manifest.yaml` before the checksum step. Implement
`report()`: print sections `CONFIG`, `INSTALLED` (one line per file),
`CONFLICTS` (one line per file), `SKIPPED`; called at the end of
every completed run. Exit 0 only when the report is printed.
Stop criterion: with `--tracks mixed` the config contains
`tracks=mixed`; report sections appear in output; missing
`--templates` argument exits 2 before any file is created.
Maps to scenarios: Interview determines the project configuration;
User adjusts proposed configuration; Final report is produced on
every completed run.

- [ ] FR 1.3 checksum-guard

Extend `scripts/manifest-init.sh` with the guard used on every run:
before anything else, if `.manifest/manifest.yaml` exists, recompute
its sha256 and compare with `.manifest/manifest.yaml.checksum`; on
mismatch print `CHECKSUM_MISMATCH` and exit non-zero without writing
anything; if the checksum file is missing print
`CHECKSUM_MISSING` and exit non-zero. The write path into
`.manifest/` must write temp files and move them into place only
after the guard passes.
Stop criterion: tampering with `manifest.yaml` in a fixture project
then re-running the script exits non-zero with `CHECKSUM_MISMATCH`
and leaves both files unchanged (compare sha256 before/after).
Maps to scenarios: Modified configuration detected; Protection
against accidental configuration overwrite.

## Wave 2 — preflight

- [ ] FR 2.1 preflight-full

Implement the full `preflight()` in `scripts/manifest-init.sh`, run
before any write. Checks, all mandatory: (1) `git` binary available
in PATH; (2) `$PROJECT` is inside a Git work tree
(`git -C $PROJECT rev-parse --is-inside-work-tree`); (3) the project
root is writable (create/remove a probe file); (4) `.manifest/` does
not exist; (5) `$TEMPLATES` exists and is readable; (6) `sha256sum`
is available. Collect all failures into a list and print one report
listing every failed check with reason and required action; exit
non-zero if any failed; make no changes to the project in this
function.
Stop criterion: fixture with no Git exits listing check 2;
fixture without `sha256sum` in PATH exits listing check 6; a
project with two failing checks lists both in one run.
Maps to scenarios: Mandatory preconditions; Not a Git repository;
Manifest already initialized; Template source unavailable; Failure
reports reason and required actions; Multiple failures; Diagnostics
only, no automatic fixing; Check happens before write.

## Wave 3 — template install

- [ ] FR 3.1 template-install-impl

Implement template installation in `scripts/manifest-init.sh` after
Preflight and config creation, using the name-mapping table (design
D4): `AGENTS.md` ← `agents.template.md`, `llms.txt` ←
`llm.template.txt`, `COMMIT_RULES.md` ← `commit-rules.template.md`,
`VERSION` ← `version.template`, `VERSIONING.md` ←
`versioning.template.md` (five files; `RELEASES.md` excluded — no
template is invented). For each: if the target exists, copy nothing
and add the path to the CONFLICTS list; else render the source
template and install it. Placeholder filling (design D7):
`{{PROJECT_NAME}}` and `{{PROJECT_PURPOSE}}` from interview data (add
an optional `--purpose` flag and interview question; empty purpose →
"Purpose: not established."), `{{INITIAL_VERSION}}` → `0.1.0` default
overridable by new `--initial-version` flag, `{{ENTRY_POINT}}` and
`{{BUILD_METHOD}}` left empty so the templates' own fallback branches
render, `{{PROJECT_CONTEXT}}` and `{{PROJECT_DIRECTORIES}}` → "Not
established.". After install: verify no `{{` remains in any installed
file, and byte-compare each installed file with a fresh deterministic
render of its template (`cmp -s`) produced in a temp location outside
the project; on failure print `INSTALL_CORRUPT <file>` and exit
non-zero, removing the temp render. Continue past conflicts (do not
abort remaining installs). Final exit codes: 0 all five installed;
3 at least one conflict; non-zero as set by Preflight failure. Feed
INSTALLED and CONFLICTS into the report of FR 1.2.
Stop criterion: fixture with existing `AGENTS.md` and `VERSIONING.md`
installs the other three, keeps both existing files byte-identical to
before, lists two conflicts, exits 3; a fresh fixture installs five
files with no `{{` anywhere in them and `PROJECT_NAME` substituted.
Maps to scenarios: Mandatory base set is installed; Single common MVP
template; Existing files are never overwritten; Conflicts are
reported and do not abort the rest; Placeholders are resolved before
install; Installed files are verified against the template render;
Report after install with one conflict; Successful init of a Git
project without context files.

## Wave 4 — verification

- [ ] FR 4.1 init-verify-scenario

Create `scripts/test-manifest-init.sh` (Bash) that mechanically
verifies the change in a temp directory: builds four fixtures (fresh
Git project; project with `AGENTS.md` and `VERSIONING.md` present;
project with tampered `manifest.yaml` checksum; directory outside a
Git work tree) and runs `scripts/manifest-init.sh` against each.
Expected results, asserted by exit code and content checks: fresh —
exit 0, five files installed, report has INSTALLED five lines,
conflicts empty, no `{{` and no `{{PROJECT_NAME}}` left in installed
files; conflicts — exit 3, three installed, two conflicts,
pre-existing files unchanged (cmp against saved copies); tampered —
exit non-zero, `CHECKSUM_MISMATCH`, config unchanged; no-git — exit
non-zero, failure report names the Git check. Clean up its temp
files on exit.
Stop criterion: `bash scripts/test-manifest-init.sh` exits 0 with a
four-line PASS summary, one PASS per fixture.
Maps to scenarios: all scenarios of the three capabilities.
