# Design: add-manifest-init-mvp

## Context

Manifest MVP decisions (brief v0.4.0, protocol 2026-11-22) fix the
behavior of `manifest-init` but not its implementation stack. This
project's own dev infrastructure (`scripts/verify.sh`,
`scripts/structure-parser.sh`, `scripts/hooks/pre-commit`) is Bash.
`manifest-init` runs in the connected project together with the same
kind of files, and the MVP must ship without a build step. Git is
mandatory for all Manifest projects (brief §6), so `bash` and `git`
are the only assumed tools at install time.

Constraints from accepted decisions:

- Working directory `.manifest` in the project root; settings in a
  separate configuration file; the configuration is stable and is not
  overwritten automatically; re-initialization is not provided; a
  protection mechanism against accidental overwrite is mandatory.
- Single common MVP template; conditional (code/doc) template sets
  are deferred to the roadmap.
- Existing files are never overwritten or merged; name conflicts are
  recorded and reported.
- Preflight is mandatory; on failure nothing is installed.
- Open questions that stay open: the configuration file format and
  the flag schema (Brief §13), hook compatibility, template
  versioning.

## Goals / Non-Goals

**Goals:**

- A single Bash entry point that performs the full MVP init cycle and
  is safe to run in a project that may contain pre-existing context
  files.
- A stable, human-readable, Git-friendly configuration file under
  `.manifest/`.
- Deterministic exit codes and a final report suitable for the
  orchestrator to consume.

**Non-Goals:**

- Git hooks and control script installation (next stage).
- Todoing/OpenSpec integration; the minimal Todoing contract.
- Specialized per-type templates; the Manifest file update process.
- Archiving of disabled templates (inclusion in MVP unresolved).
- Automatic fixing of Preflight problems (diagnose and report only).

## Decisions

- **D1. Implementation language: Bash** (user decision, 2026-11-22).
  Consistent with existing `scripts/*.sh`; no build step; no runtime
  dependency beyond Git/Bash, which MVP Preflight already assumes.
  Rust is reserved for Todoing and later core components.
- **D2. Configuration file: `.manifest/manifest.yaml`** — a minimal
  flat YAML-like key/value file. This is an implementation choice to
  satisfy "a separate configuration file" without turning the open
  format question into a requirement: the file is parsed only by
  simple `grep`/`sed` in MVP, no YAML library. The format can be
  revised in a later change without touching installed projects'
  semantics (the file is stable and never auto-overwritten).
  Alternative considered: JSON — harder to edit by hand, rejected
  for MVP.
- **D3. Accidental-overwrite protection: content checksum.**
  `.manifest/manifest.yaml.checksum` (sha256 of the config) is written
  at init; every re-run of the init entry point first verifies the
  checksum against the file; on mismatch or on any existing
  `.manifest/` the tool refuses to re-initialize and reports
  `REINIT_REFUSED`. Writing the config itself is a single
  `install -m 644` of a temp file into the verified-empty directory.
- **D4. Template source: `docs/templates/` of the Manifest
  repository.** The MVP copies the mandatory base set defined in the
  brief (`AGENTS.md`, `llms.txt`, `COMMIT_RULES.md`, `VERSION`,
  `VERSIONING.md`, `RELEASES.md`). The Manifest repo location is
  passed to the script as an argument/flag, not hardcoded — MVP
  runs from a checkout, not from a published distribution.
- **D5. Conflict policy: skip and report.** A target file that exists
  is skipped untouched and listed as a conflict in the final report
  and in the exit status; the install is otherwise completed (no
  rollback of already-copied files), matching "no merging, existing
  files are not overwritten". Partial install state is visible in the
  report, so the user decides.
- **D6. Preflight checks are diagnostics only**: git presence,
  write permission in the project root, absence of `.manifest/`,
  availability of the template source directory. On failure: exit
  non-zero with reason and required action; no partial writes.

## Risks / Trade-offs

- Bash parsing of the config is minimal (grep-based); a richer flag
  schema will require revisiting the parser — accepted, MVP flags are
  few.
- Skipping conflicts may leave a project half-connected; mitigated by
  the conflict list in the report and exit code.
- `sha256sum` availability: assumed on Git-for-Windows/WSL/Linux;
  Preflight verifies it and reports a missing tool instead of failing
  mid-install.
