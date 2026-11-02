**Language.** Reply to the user in Russian. Default all artifacts
(docs, code, identifiers, comments, commits) to English unless told
otherwise. Reason in English.

**temp/.** Temporary storage for files needed during work (scripts, intermediate artifacts, anything not part of the app). All temporary files go here — never write them elsewhere. `temp/` is cleaned periodically, never while an agent is working on app functionality; the user may clear it manually or ask the model to.

**Project structure.** This is the head project. It contains subordinate
projects (skills) under `skills/`. Navigation map: `llms.txt`.

- When the user asks to work with a sub-project from this (head) folder,
  read that sub-project's `AGENTS.md` before working on it.
- Every new sub-project must be registered here with a link to its
  `AGENTS.md`.

Sub-projects:

- `skills/compress-context/` — context-compression skill.
  Agent file: `skills/compress-context/AGENTS.md`.
- `skills/compress-context-benchmark/` — benchmark for the compression skill.
  Agent file: `skills/compress-context-benchmark/AGENTS.md`.

**Plans.** Plan files live in `docs/plans/`. Plan files are stored compressed;
compression is done with the compress-context skill. Always read the English
version (`.en.md`) of a plan. If no English version exists, read the version
in any language. English takes priority.

**Rules.**

* Versioning: `VERSIONING.md`
* Releases: `RELEASES.md`
* Commits: `COMMIT_RULES.md`
* Access boundaries: `.llmignore` — read first; access ignored paths only with explicit permission.

**Templates.** Templates in `docs/templates/` are source material for new
projects, not live documents. They are listed in `.llmignore` — do not read
them as project rules and do not link to them.