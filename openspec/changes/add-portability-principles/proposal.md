# Proposal: add-portability-principles

## Why

A static audit (2026-11-22) and the portability analysis that followed
it showed that Manifest's autonomy and portability are currently
implicit: they were achieved by one-off cleanups (removing machine
paths, foreign-project mentions, and an undeclared Python dependency
from the plans rule) rather than by standing principles. Nothing
prevents regressions: no automated check stops a machine path or a
model name from re-entering a public file, templates reference files
that are never installed (`commit-rules.md`, `releases.md`), and
infrastructure scripts depend on tools that are not declared anywhere
(`python` in `verify.sh`, `perl` in `manifest-init`, `sha256sum` that
does not exist on macOS by default).

Manifest must stay autonomous and universal: a public file must be
usable in any project, on any OS, with any AI harness, without leaking
facts about the machine or the setup where Manifest is developed.

## What Changes

1. Autonomy and portability become explicit Manifest architectural
   principles. The wording of the principle section is prepared as
   part of this change (design D8) and recorded in the architecture
   docs at implementation time.
2. A new capability `portability-principles` defines requirements for
   public files, scripts, and templates, including: the check scope
   follows installation and distribution (a file Manifest starts
   distributing to connected projects automatically enters the check
   scope), and the RU/EN bilingual editions requirement.
3. Public `AGENTS.md` loses model/harness-specific facts (Qwen3.8-27B,
   ZCode watchdog); the calibration rule is kept, stated harness-free.
4. `scripts/verify.sh` drops its undeclared Python dependency; fixture
   generation is rewritten in portable Bash/awk.
5. Template references use canonical installed filenames
   (`COMMIT_RULES.md`, `VERSIONING.md`, …). `RELEASES.md` is classified
   per the Architecture Brief: part of the mandatory base set,
   temporarily not installed because no template exists — not a
   conditional template.
6. A centralized external dependency register documents every external
   tool, its purpose, and its scope of use; `perl` (manifest-init
   rendering) and portable SHA-256 detection are documented there.
7. The stored checksum records which SHA-256 tool produced it; the
   checksum file format and the affected test fixtures are updated
   (design D6, FR 3.5).
8. `.gitattributes` establishes predictable line-ending behavior,
   covering shell scripts, templates, and `scripts/hooks/*` (including
   the extension-less `pre-commit`).
9. Automated autonomy/privacy checks are added to `verify.sh`; they
   validate Manifest's own public files, scripts, and templates only —
   they never impose requirements on projects that use Manifest. Where
   a mechanical definition is insufficient (e.g. "unrelated external
   project" mentions), a mandatory human review complements the
   automated checks.
10. Manifest documents are maintained in two editions (Russian
    authoritative, English translation) with matching content. The
    bilingual requirement is confirmed by the user (2026-11-22) and
    recorded in the `portability-principles` capability; no Roadmap
    entry is claimed beyond what the Roadmap actually contains.

## Capabilities

### New: portability-principles

Requirements covering: forbidden content in public files, check scope
that follows installation and distribution, portable Bash scripts
without GNU-specific utility dependencies, declared dependencies only,
canonical template references, bilingual RU/EN editions, predictable
line endings, automated checks complemented by human review where
mechanical definitions are insufficient.

### Modified: template-install

Template cross-references must match canonical installed filenames;
`RELEASES.md` is a base-set file temporarily not installed.

### Modified: manifest-init

Install-time dependencies must be limited to those declared in the
external dependency register.

### Modified: preflight

SHA-256 availability must be checked portably (a working SHA-256 tool,
not a specific binary name); the stored checksum records the tool.

## Impact

- Affected: `AGENTS.md`, `scripts/verify.sh`, `docs/templates/*`,
  `manifest-init.sh` (SHA-256 detection, checksum format), new
  `.gitattributes`, new dependency register documents, `llms.txt`
  (link to the register), architecture docs (brief + decisions —
  during implementation).
- Not affected: connected-project behavior; the MVP install set stays
  five files; no integration mechanism with other projects is
  designed here.
