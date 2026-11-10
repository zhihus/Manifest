**Language.** Reply to the user in Russian. Default all artifacts
(docs, code, identifiers, comments, commits) to English unless told
otherwise. Reason in English. When starting development of a new
document file, create the Russian version (`.ru.md`) alongside the
English one. **RU/EN workflow:** `.ru.md` is a working draft for the
user's review; the user approves RU, then the agent translates it into
the English (final) file; RU may be deleted later.

**Transcription format.** In the structure file's header transcription: each
line of the real document comes first, followed by a line starting with
`Описание:`/`Description:` — an annotation describing how that line should
look and what it must contain.

**temp/.** Temporary storage for files needed during work (scripts, intermediate artifacts, anything not part of the app). All temporary files go here — never write them elsewhere. `temp/` is cleaned periodically, never while an agent is working on app functionality; the user may clear it manually or ask the model to.

Type: **doc**.

**Project structure.** This is the head project. Navigation map: `llms.txt`.

- Register every new sub-project in `llms.txt` with a brief comment.

Sub-projects:

- `handy/dictation-scrubber/` — **separate project** since 2026-11-05:
  `C:\WorkProjects\handy-dictation-scrubber\` (history exported from
  this repo via subtree split). Do not edit it here.
- **Skills** — `C:\WorkProjects\skills\` is a plain shared folder
  (no git of its own) since 2026-11-10. Each subfolder is an
  independent project with its own repository (`compress-context`,
  `compress-context-benchmark`, `eval-analyze`, …). Do not edit them
  here; work inside the respective project folder.
- **context-files-guard** — **separate project** since 2026-11-05:
  `C:\WorkProjects\context-files-guard\` (change `add-context-files-guard`
  exported from `openspec/changes/` via subtree split). Do not edit it here.

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
* Line length: in final English documents, keep every line ≤ 100
  characters; Russian working drafts have no length limit.

**Templates.** Templates in `docs/templates/` are source material for new
projects, not live documents. They are listed in `.llmignore` — do not read
them as project rules and do not link to them.

**Task-size calibration.** Measured on the sequential-ratio-compression
run (Qwen3.8-27B): a doc-editing task takes the executor about 2-3 minutes;
a code task with a scripted verification scenario, about 5-8 minutes.
When unsure about task size, split by deliverable files, not by characters.
The executor commits after each completed stage (protection against the
ZCode 600 s subagent watchdog bug). Heavy verification is split into its
own task, not attached to the implementation task. If an executor exceeds
the 10-minute limit, the task is too large: split it in the next spec
revision and record the fact in tasks.md.
