# PLAN-project-structure-head-subprojects — Stage 3

> Russian version: PLAN-project-structure-head-subprojects-stage-3.ru.md
> Status: partially implemented

## Context
The head project `Manifest` and its sub-projects (skills) are documentation projects (no code). Templates fall into 2 categories: for **code** projects (like VoiceCaptureEngine) and for **documentation** projects; some files are common (currently `AGENTS.template.md` does not differ). Stage 3: templates for documentation projects, updates to RELEASES, SETTINGS, OpenSpec rules.

## What will be done

### B1. `doc-content-rules.template.md`
Rules template for **documentation** projects (projects that produce documentation, not code). Content:
- Rules for documentation projects (analog of `code-rules.template.md`, but for documentation): Clarity, Accuracy, Completeness, Consistency, Structure, Change Discipline, Verification.
- **Context-files protection block** (TEMPORARY): when modifying agent/rules files — show the changes + review + explicit user consent before commit (until a Git Hook exists).
- **Git workflow: UNRESOLVED** (see "Unresolved questions").

**Not implemented** — partial = not implemented. Done only when all points, including the git workflow, are complete.

### B2. `SETTINGS.template.md` ✅
Settings-rules template (modeled on `SETTINGS.md` from VoiceCaptureEngine, but as a template with placeholders).
**Done** — created as a placeholder template (no local source; VoiceCaptureEngine is external).

### B3. `RELEASES.template.md` (update) ✅
- Branches: `dev`/`master` → `develop`/`master`.
- `develop` — all development (including documentation projects).
- `master` — approved documents / release-ready.
- Same scheme for code projects.
- Branch for OpenSpec changes: branch name tied to OpenSpec task naming (see `open-spec-rules.template.md`).
**Done** — full file updated; compressed twin regenerated via the compress-context skill.

### B4. `open-spec-rules.template.md` ✅
General OpenSpec task-naming rules (from `compress-context/open-spec-rules.md`): FR prefix, N.M numbering, kebab-case, wave. These are **general** rules (not skill-specific).
**Done** — copied from the local source as a template.

### B5. Cross-references ✅
Mutual links between the RU and EN files of each stage (RU→EN, EN→RU).
**Done** — all plan files carry mutual RU/EN references.

### B6. Rule for the head project (Manifest) ✅
Templates in `docs/templates/` are source material, not real documents; nothing references them. Manifest-specific; goes into the live `AGENTS.md`.
**Done** — stop-sign rule added to the live `AGENTS.md`.

## Done in this session (not part of this plan)

- Moved `project-manifest.md` from project root to `docs/` (alongside other manifest files).
- Removed all links to manifest files (`project-manifest.md`, `docs/MANIFEST.md`, `docs/MANIFEST.compact.md`) and to the non-existent `docs/context-files-guard.md` from `llms.txt`. The manifest is a human-facing document the model should not read; it is not referenced in any navigation file.

## Unresolved questions
1. **Git workflow for documentation projects** (branch per task, merge into develop, stop-and-report): where to add it — unresolved. Possibly a separate agent file.
2. **Separate project-context file** for documentation projects: possibly an agent file. Unresolved.

## Files
- `docs/templates/doc-content-rules.template.md` — new (documentation projects + context protection)
- `docs/templates/SETTINGS.template.md` — new (settings rules)
- `docs/templates/open-spec-rules.template.md` — new (OpenSpec task naming)
- `docs/templates/RELEASES.template.md` — updated (develop/master, OpenSpec branches)
- `AGENTS.md` — updated (rule about templates: source material, not real documents; nothing references them)

## Verification
- `doc-content-rules.template.md` — rules for documentation projects + context-protection block.
- `SETTINGS.template.md` — placeholders for settings.
- `open-spec-rules.template.md` — FR, N.M, kebab-case, wave.
- `RELEASES.template.md` — branches `develop`/`master`; OpenSpec branches mentioned.
- `AGENTS.md` contains the template rule; `docs/templates/` does not appear in `llms.txt` / `AGENTS.md`.
- All links in `llms.txt` and `AGENTS.md` resolve to files that actually exist.