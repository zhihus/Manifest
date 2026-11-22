# Design: add-portability-principles

## Context

The audit and analysis of 2026-11-22 confirmed that autonomy and
portability hold today only by convention. The decisions below are
project decisions of THIS change, confirmed by the user in the review
of 2026-11-22; they are not earlier-approved architecture decisions
and are recorded in the decision register only when FR 1.1 implements
this change.

Constraints honored: no mention of `compress-context` or
`context-files-guard` is removed (their role in the Manifest
ecosystem is decided separately); no integration mechanism is
designed; the RU/EN bilingual editions requirement is confirmed by the
user (2026-11-22) and recorded in this change.

## Goals / Non-Goals

**Goals:**

- Standing principles in the architecture docs and OpenSpec specs.
- Mechanical, reproducible checks for public-file hygiene, with a
  check scope that follows installation and distribution.
- Explicit dependency register covering every external binary.
- Portable script behavior (Linux, macOS, Windows via Git Bash).
- Bilingual RU/EN editions kept in correspondence.

**Non-Goals:**

- Distribution packaging of manifest-init.
- RU/EN completeness of the workflow rules content (not claimed to be
  on the Roadmap; the bilingual editions requirement of documents is
  in scope instead).
- Integration with other projects; cross-platform CI matrix.
- Changing the MVP install set or earlier recorded architecture
  decisions.

## Decisions

- **D1. Check scope is principle-based, with an explicit current
  list.** Scope principle (user decision 2026-11-22): every file
  Manifest installs into connected projects, every file Manifest
  distributes to them, and Manifest's navigation files (`AGENTS.md`,
  `llms.txt`) are checked; a file enters the scope automatically as
  soon as it becomes installed or distributed (this covers a future
  distribution of `workflow/` or parts of it — no new decision
  needed). Currently checked (closed list): `AGENTS.md`, `llms.txt`,
  `docs/templates/` (all files), `openspec/specs/` (all files),
  `docs/manifest.md`, `docs/manifest.compact.md`,
  `docs/project-manifest.md`, root rule files (`VERSIONING.md`,
  `commit-rules.md`, `releases.md`, `RELEASES.md`),
  `openspec-rules.md`. Excluded on purpose: `docs/architecture/`
  (decision records — approved decisions there mention specific
  harnesses and models as recorded facts; changing them is out of
  scope), `openspec/config.yaml` (local OpenSpec harness context),
  `docs/plans/` and `openspec/changes/archive/` (historical records),
  `workflow/` (not distributed to connected projects today; the role
  table there records an approved model-specific orchestrator
  decision; it enters the scope automatically upon distribution, per
  the scope principle above).
- **D2. Forbidden content is a closed mechanical pattern list,
  complemented by human review.** Patterns: Windows absolute paths
  (`C:\…`, `C:/…`), Unix home/user paths (`/home/<user>/…`,
  `/Users/<name>/…`), `C:\Users`, `C:\WorkProjects`, personal email
  addresses, and harness/model identifiers (`ZCode`, `Qwen`, `GLM-`).
  Framework components named in the architecture
  (`compress-context`, `context-files-guard`) are NOT forbidden —
  they are part of the Manifest ecosystem, not unrelated external
  projects. "Unrelated external project" mentions have no mechanical
  closed definition; the automated check covers the closed pattern
  list above, and a human reviewer MUST additionally review the
  public-file scope for unrelated-project mentions where the
  mechanical definition is insufficient (user decision 2026-11-22).
- **D3. `verify.sh` fixture generation is rewritten in Bash/awk.**
  The Python heredoc wrote a fixed fixture file; a Bash/awk
  implementation reproduces the same bytes. Python disappears from
  the dependency set entirely.
- **D4. Canonical filenames = exactly what Manifest installs.**
  Template references to base-set files use uppercase names as
  installed: `COMMIT_RULES.md`, `VERSIONING.md`. `RELEASES.md` is
  classified per the Architecture Brief (§4): part of the mandatory
  base set, temporarily not installed because no template exists —
  not a conditional template. References to conditional files use
  their canonical planned names (`CODE_RULES.md`, `TEST_RULES.md`,
  `LOG_RULES.md`); these are declared conditional, not dangling.
  Lowercase `commit-rules.md` / `releases.md` references in templates
  are corrected.
- **D5. The external dependency register lives at
  `docs/architecture/external-dependencies.ru.md` (+ `.en.md`,
  RU authoritative) — the directory is exempt from the `*.ru.md`
  ignore rule and is the established home of decision records.
  Register entries: tool, purpose, scope (which scripts), detection
  method. Initial entries: `git`, `bash`, a SHA-256 tool
  (`sha256sum`, or `shasum -a 256` on macOS — detected at runtime),
  `perl` (manifest-init template rendering only — documented, not
  replaced), `mktemp`, `awk`, `cmp` (coreutils), `date`, `grep`,
  `sed`. The initial list is illustrative: the binding requirement is
  that every binary invoked by `scripts/*.sh` has an entry (enforced
  by the FR 1.2 stop criterion and FR 4.2 check). `python` is
  removed, not registered. D1–D8 are decisions of this change; the
  register documents perl as an existing implementation fact, not as
  an earlier-approved decision.
- **D6. SHA-256 is detected, not assumed; the checksum records the
  tool.** `manifest-init` preflight accepts any of `sha256sum` or
  `shasum -a 256`; the chosen tool is used consistently for the
  checksum guard and its verification. The stored checksum file
  records which tool produced it; the checksum file format and the
  affected test fixtures are updated accordingly (FR 3.5). Risk:
  macOS `shasum -a 256` output format differs (`hash  -` vs
  `hash  file`); the detection layer normalizes to the first field
  only.
- **D7. `.gitattributes` normalizes line endings:** `* text=auto`
  plus explicit `eol=lf` for `*.sh`, `docs/templates/*`, and
  `scripts/hooks/*` — including the extension-less `pre-commit`
  (scripts and template bytes must be stable across platforms;
  byte-comparison in manifest-init depends on it). Exact content is
  fixed at implementation and verified by `git check-attr`.
- **D8. Architecture docs are updated during implementation, in a
  separate commit, by the sync procedure used for earlier brief
  updates (RU authoritative, EN translation, version bump).** The
  wording of the new principle section is prepared as part of this
  change (it is not an open user question); Bilingual editions: RU
  authoritative, EN translation, content in correspondence — per the
  user decision of 2026-11-22.

## Risks / Trade-offs

- The forbidden-pattern check can produce false positives on
  legitimate content (e.g., a documented path example). Mitigated by
  the closed scope list (D1) and an explicit allowlist mechanism in
  the check implementation.
- `.gitattributes` renormalization can produce a one-time diff noise
  across the tree; implementation must renormalize deliberately and
  keep it a separate commit.
- The scope principle (D1) makes the check scope grow with
  distribution; the automated pairing check (bilingual editions) and
  the closed pattern list keep the growth mechanical.

## Unresolved Questions

None. The earlier questions U1 (scope of `workflow/`) and U2
(wording of the principle) were resolved by the user and by D8
respectively: U1 became the scope principle in D1, U2 is withdrawn —
the wording is prepared as part of this change.
