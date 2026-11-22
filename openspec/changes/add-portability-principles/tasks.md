# Tasks: add-portability-principles

## 1. Principles and register

- [x] FR 1.1 architecture-principle-docs

Add autonomy and portability as an explicit principle to
`docs/architecture/architecture-brief.ru.md` (new short section:
public files free of machine paths, personal data, unrelated-project
references, and model/harness-specific instructions; check scope
following installation and distribution; portable Bash scripts
without GNU-specific utility dependencies; declared external
dependencies only) and translate to `.en.md`; add matching entries
to `docs/architecture/architecture-decisions.ru.md` (+ `.en.md`),
stating these are decisions of the change `add-portability-principles`
confirmed by the user in the review of 2026-11-22 (not
earlier-approved decisions). Bump brief/decisions versions per
`workflow/file-metadata-change-rules`. Do not touch
`compress-context` / `context-files-guard` mentions. Separate commit.
Stop criterion: brief RU+EN contain the new section with versions
bumped; decisions registers contain the new entries; no other brief
content changed (diff review).
Maps to scenarios: Machine path in a public file; Scripts are
portable Bash scripts without GNU-specific utility dependencies.

- [x] FR 1.2 dependency-register

Create `docs/architecture/external-dependencies.ru.md` (authoritative)
and `external-dependencies.en.md`. Entries (tool, purpose, scope,
detection): `git` (all scripts; PATH), `bash` (interpreter),
SHA-256 tool (`sha256sum` or `shasum -a 256`, detected; checksum
guard), `perl` (manifest-init template rendering only; preflight checks `perl -e 'exit 0'`),
`mktemp`, `awk`, `cmp`, `date`, `grep`, `sed` (coreutils/shell
basics where they carry logic). Mark the initial list illustrative:
the binding rule is that every binary invoked by `scripts/*.sh` or hooks under `scripts/hooks/` has
an entry. Explicitly note Python was removed and is not a
dependency. Link the register from `llms.txt` (Directories section,
one line). Separate commit.
Stop criterion: both files exist with identical entry sets; every
binary invoked by `scripts/*.sh` or `scripts/hooks/*` (grep over the scripts and hooks) has an
entry; `llms.txt` links the register.
Maps to scenarios: External dependency register exists and is
referenced; Perl rendering dependency documented.

## 2. Public files

- [x] FR 2.1 agents-deharness

Rewrite the task-size calibration paragraph in `AGENTS.md`
(measured 2-3 min doc / 5-8 min scripted-verification task, split by
deliverables, executor commits per stage, heavy verification split,
>10 min → split): remove the model name and the harness watchdog
reference, keep all numeric guidance and the commit-per-stage rule,
phrase the reasons harness-free. English-only file; lines ≤100
chars. Separate commit.
Stop criterion: `grep -iE 'qwen|zcode|glm' AGENTS.md` finds nothing;
the calibration numbers and rules are unchanged in the diff.
Maps to scenarios: Public files carry no model- or harness-specific
instructions.

## 3. Scripts and templates

- [x] FR 3.1 verify-fixture-bash

In `scripts/verify.sh`, replace the Python heredoc fixture generator
with a Bash/awk writer producing byte-identical fixture content
(same 140-char title, metadata block, numbered sections, seeded
violations). Remove the Python invocation. Keep the EXIT-trap temp
cleanup and rc propagation. Separate commit.
Stop criterion: `python` absent from verify.sh; the generated fixture
file is byte-identical to the Python-generated one (cmp against a
saved copy); `bash scripts/verify.sh` exits 0 with a clean tree and
fails on the seeded parser test when the parser is broken.
Maps to scenarios: Scripts are portable Bash scripts without
GNU-specific utility dependencies; Repository verification includes
automated autonomy checks.

- [x] FR 3.2 template-canonical-refs

In `docs/templates/agents.template.md` and `llm.template.txt`,
change lowercase references `commit-rules.md` → `COMMIT_RULES.md`
and `releases.md` → `RELEASES.md`; keep `CODE_RULES.md`,
`TEST_RULES.md`, `LOG_RULES.md`, `VERSIONING.md` as canonical
conditional/base names. Do not change placeholder or conditional
syntax. Separate commit.
Stop criterion: grep finds no `commit-rules.md`/`releases.md`
lowercase refs in `docs/templates/`; manifest-init test script still
passes (9/9) since rendered content changes are inside AGENTS.md/
llms.txt bodies.
Maps to scenarios: Canonical reference names.

- [x] FR 3.3 sha256-portability

In `scripts/manifest-init.sh`, add SHA-256 tool detection: accept
`sha256sum` or `shasum -a 256` (normalize output to the hash field);
preflight requires at least one and reports which; the checksum
guard and config checksum use the detected tool. Update
`scripts/test-manifest-init.sh` with a regression fixture running
the init with the sha256sum tool absent from PATH but a `shasum`
stub available (PATH-manipulated). Separate commit.
Stop criterion: new fixture passes (init succeeds via the shasum
stub, checksum written and verified); existing 9 fixtures still
pass; no sha256sum-specific code path left outside the detection
helper.
Maps to scenarios: macOS without sha256sum; No SHA-256 tool at all.

- [x] FR 3.4 gitattributes

Add `.gitattributes`: `* text=auto`; explicit `eol=lf` for `*.sh`,
`docs/templates/*`, and `scripts/hooks/*` (covering the
extension-less `pre-commit`); binary markers if any tracked binaries
exist. Renormalize tracked files in the same commit. Separate
commit (kept apart from logic changes to isolate diff noise).
Stop criterion: `git check-attr` shows `eol=lf` on a script, a
template, and `scripts/hooks/pre-commit`; `git status` clean after
renormalization; verify.sh OK.
Maps to scenarios: Template bytes stable across platforms.

- [x] FR 3.5 checksum-format-tool-record

Change the checksum file format so the stored checksum records the
SHA-256 tool that produced it (design D6): extend
`manifest.yaml.checksum` with the tool name (detection helper from
FR 3.3), keep the guard's hash extraction robust to the new field,
and update the checksum-related fixtures in
`scripts/test-manifest-init.sh` (tampered/corrupt/reinit cases) for
the new format. Separate commit.
Stop criterion: checksum file written by the shasum stub path
records `shasum`; by the sha256sum path records `sha256sum`; guard
and re-verification pass on both; all existing fixtures pass with
the new format.
Maps to scenarios: macOS without sha256sum; No SHA-256 tool at all.

- [x] FR 3.6 perl-preflight

In `scripts/manifest-init.sh`, verify during preflight that Perl is
available and can execute a trivial program (`perl -e 'exit 0'`)
before any project files are written. Add a regression fixture using
a non-working Perl stub and verify that installation fails with an
actionable message and leaves the project unchanged.
Stop criterion: the Perl stub fixture fails preflight before creating
`.manifest`; normal installations and all existing fixtures pass.
Maps to scenarios: Perl is unavailable.

## 4. Automated checks

- [x] FR 4.1 verify-autonomy-patterns

Extend `scripts/verify.sh` with an autonomy section: run the
forbidden-pattern checks (design D2 pattern list) over the check
scope (design D1, including the bilingual-pairing check: every
English edition in scope must have a `*.ru.md` sibling); report
file and line; route judgment findings (unrelated-project mentions
outside the closed patterns, content correspondence) to the human
review output of the section. Separate commit.
Stop criterion: with a clean tree verify.sh exits 0; planting a
`C:\Users\…` line in a fixture copy of a public file makes verify.sh
exit 1 reporting file and line; removing an `*.ru.md` sibling of a
fixture `.en.md` makes verify.sh exit 1; removing it restores 0.
Maps to scenarios: Machine path in a public file; Clean tree; Model
name in AGENTS.md; Unrelated project mention; English edition
without Russian sibling; Paired editions; Seeded violation is
caught.

- [x] FR 4.2 verify-scope-and-register

Add to the verify.sh autonomy section: the scope principle check
(any file under the install/distribution source lists of design D1
is inside the checked set) and the register cross-check — every
external binary invoked by `scripts/*.sh` or `scripts/hooks/*` must have an entry in
`docs/architecture/external-dependencies.ru.md` (simple name list
extracted from the register); allowlist mechanism for false
positives (inline comment marker). Do not check `docs/architecture/`
content beyond the register cross-check, `workflow/`,
`openspec/config.yaml`, `docs/plans/`, `openspec/changes/archive/`
(design D1 exclusions). Separate commit.
Stop criterion: adding an undeclared binary call to a fixture copy
of a script makes verify.sh exit 1 naming the binary; registering
it restores 0; moving a file into a distributed-source list pulls it
into the checked set (fixture test). Human review of changed shell
scripts covers constructs outside the conservative scanner grammar.
Maps to scenarios: File becomes distributed; Undeclared binary; Shell construct beyond scanner grammar.

## 5. Verification

- [x] FR 5.1 portability-verify-scenario

Add `scripts/test-portability.sh`: seeds each forbidden pattern
class into a fixture copy (not the real file) and asserts the
verify.sh autonomy section catches it and reports the right file;
asserts a clean tree passes; asserts the register covers all
invoked binaries; asserts the human-review routing line appears in
the verify.sh output; cleans up temp files. Separate commit.
Stop criterion: `bash scripts/test-portability.sh` exits 0 with one
PASS per pattern class, one PASS for the clean tree, and one PASS
for the register coverage.
Maps to scenarios: all scenarios of portability-principles.
