**Project boundaries and publication.** This repository is an independent
project. Connected projects remain autonomous; reuse of Manifest is optional
and does not authorize changing another project to fit Manifest. Read
`docs/project-boundaries-and-publication.ru.md` before planning publication.
Local work may use multiple branches and contain local-only support files.
Only the reviewed, distilled result is integrated into and pushed from
`develop`. Never publish local working branches, personal/customer data,
local paths, secrets, temporary files, or unrelated project material. Do not
create private GitHub mirrors. When unsure whether a file belongs in the
public product, keep it local and ask the user.

**Language.** Reply to the user in Russian. Default code, identifiers,
comments, and commit messages to English. Maintain document editions
in Russian and English: `.ru.md` is authoritative and is the version
the user reviews; `.en.md` is its faithful translation. Create or
update the Russian edition first, then synchronize the English
translation. Never delete the Russian edition or treat English as
authoritative. Reason in English.

**Transcription format.** In the structure file's header transcription: each
line of the real document comes first, followed by a line starting with
`Описание:`/`Description:` — an annotation describing how that line should
look and what it must contain.

**temp/.** Temporary storage for files needed during work (scripts, intermediate artifacts, anything not part of the app). All temporary files go here — never write them elsewhere. `temp/` is cleaned periodically, never while an agent is working on app functionality; the user may clear it manually or ask the model to.

Type: **doc**.

**Project structure.** This is the head project. Navigation map: `llms.txt`.

- Register every new sub-project in `llms.txt` with a brief comment.

**Plans.** Plan files live in `docs/plans/`. Plan files are stored
compressed; the agent must perform context compression before storing
or updating a plan, using an available context-compression skill or
mechanism of its own choice, and the compression must preserve
invariants, constraints, and technical values. Always read the Russian
authoritative version (`.ru.md`). The English version (`.en.md`) is
a translation and never takes priority. If no Russian version exists,
read the available version and create the Russian edition when the plan
is next updated.

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

**Task-size calibration.** Measured values from a calibration run: a
doc-editing task takes the executor about 2-3 minutes; a code task
with a scripted verification scenario, about 5-8 minutes. When unsure
about task size, split by deliverable files, not by characters. The
executor commits after each completed stage (protection against the
subagent 600-second watchdog cutoff). Heavy verification is split
into its own task, not attached to the implementation task. If an
executor exceeds the 10-minute limit, the task is too large: split it
in the next spec revision and record the fact in tasks.md.
