**Language.** Reply to the user in Russian. Default all artifacts
(docs, code, identifiers, comments, commits) to English unless told
otherwise. Reason in English.

**temp/.** Temporary storage for files needed during work (scripts, intermediate artifacts, anything not part of the app). All temporary files go here — never write them elsewhere. `temp/` is cleaned periodically, never while an agent is working on app functionality; the user may clear it manually or ask the model to.

Type: **doc**.

**Project structure.** This is the head project. It contains subordinate
projects under `skills/` and `handy/`. Navigation map: `llms.txt`.

- Register every new sub-project in `llms.txt` with a brief comment.

Sub-projects:

- `skills/compress-context/` — context-compression skill.
  Agent file: `skills/compress-context/AGENTS.md`.
- `skills/compress-context-benchmark/` — benchmark for the compression skill.
  Agent file: `skills/compress-context-benchmark/AGENTS.md`.
- `handy/dictation-scrubber/` — offline Handy dictation cleaning utility
  (regex fillers + removal logging, transcription-hook integration).
  Agent file: `handy/dictation-scrubber/AGENTS.md`.

**Two experimental reference projects.**
Manifest (this project, root) is documentation-based; InvestPlan
(`C:\WorkProjects\InvestPlan`) is code-based. Their context files are the
source for the final manifest: requirements for these files (checks,
auxiliary skills, applications).

**Plans.** Plan files live in `docs/plans/`. Plan files are stored compressed;
compression is done with the compress-context skill. Always read the English
version (`.en.md`) of a plan. If no English version exists, read the version
in any language. English takes priority.

**Rules.**

* Versioning: `VERSIONING.md`
* Releases: `releases.md`
* Commits: `commit-rules.md`
* OpenSpec tasks: `openspec-rules.md`
* Access boundaries: `.llmignore` — read first; access ignored paths only with explicit permission.
* Copy-paste output (prompts, commands, code, config) → fenced code block, not plain text.

**Templates.** Templates in `docs/templates/` are source material for new
projects, not live documents. They are listed in `.llmignore` — do not read
them as project rules and do not link to them.