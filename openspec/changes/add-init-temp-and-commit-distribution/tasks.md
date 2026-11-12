# Tasks: add-init-temp-and-commit-distribution

## 1. Rules and agent files

- [x] FR 1.1 Create temp folder rules

  Create `workflow/temp-folder-rules.ru.md` per
  `workflow/file-structure-rules.ru.md` (metadata header: Status
  draft, Type document, Version 1.0.0, Updated 2026-11-12; numbered
  sections). Content: section 1 — folder placement and naming
  (`temp/` lowercase, project root, listed in `.gitignore`); section
  2 — write anything, delete nothing (unless the user explicitly
  asks); section 3 — no console deletion commands (`rm`,
  `Remove-Item`, equivalents): dangerous, require user confirmation,
  interrupt the process; stop and report instead; section 4 — the
  standard subagent boilerplate block, quoted verbatim in a code
  fence, marked as the single source of the text for subagent
  delivery.
  Stop criterion: the file exists, follows the structure rules,
  contains all four sections and the fenced boilerplate.
  Maps to scenarios: correct placement, agent must not clean up,
  deletion needed, subagent knows the rule.

- [x] FR 1.2 Create the agent file

  Create `workflow/agent-rules.ru.md` — plain structure modeled on
  `docs/templates/agents.template.md` (NO metadata header, NO
  Examples footer, parser not applied). Content: title `# Agent
  Rules`; section `## Commits` with the single line `* commit-rules`
  (the only file reference); section `## Preserved content` framed by
  `<!-- manifest:preserved start -->` and
  `<!-- manifest:preserved end -->` comments, empty inside, with a
  one-line note above the frame explaining the marker semantics
  (rules transferred from the project's original agent file during
  archive-based replacement; only the substance — the rules the
  model must follow — is transferred; the original file's structure
  is cut away).
  Stop criterion: the file exists, references only `commit-rules`,
  contains the empty marker frame.
  Maps to scenarios: file shape, first release content, empty block
  on fresh init, substance-only transfer, name.

- [x] FR 1.3 Create the agent file accumulator draft

  Create `workflow/agent-rules-draft.ru.md` — a free-form accumulator
  (no structure-rules header required) collecting everything known
  about the agent file content, assembled from `docs/templates/`:
  project (name, purpose, context, entry point from
  `agents.template.md`); files and access (`.llmignore` first, temp/
  reference); base rules (current task, test before code, copy-paste
  in fenced blocks); code (`code-rules.template.md`); tests
  (`code-test-rules.template.md`); logging (`code-log-rules.template.md`);
  git and commits (`commit-rules.template.md`); versioning and
  releases (`versioning.template.md`, `code-releases.template.md`);
  OpenSpec tasks (`open-spec-rules.template.md`); navigation
  (`llm.template.txt`). Not included: `llmignore.template`
  (separate artifact), `settings.template.md` (project settings, not
  agent rules), `doc-content-rules.template.md` ({{PENDING}} stub).
  Mark the file header: "Accumulator draft — material for future
  agent file releases; not shipped in the distribution."
  Stop criterion: the file exists and covers all listed sections.
  Maps to scenarios: file shape.

## 2. Delivery and registration

- [x] FR 2.1 Wire the temp block into subagent definitions

  Edit the four user-level subagent definitions
  (`C:/Users/<user>/.zcode/agents/coder.md`, `doccer.md`,
  `code-reviewer.md`, `doc-reviewer.md`): append a `## temp/ folder`
  section containing the boilerplate block copied verbatim from
  `workflow/temp-folder-rules.ru.md` (write anything; delete
  nothing; no console deletion commands — stop and report instead).
  Stop criterion: all four files contain the section with the
  verbatim block text.
  Maps to scenarios: subagent knows the rule.

- [x] FR 2.2 Register files and create the registry

  1. Add entries for `temp-folder-rules`, `agent-rules` and
     `connected-projects` to `llms.txt` following its existing
     entry style.
  2. Create `workflow/connected-projects.md` with the format:
     one entry per project — name (kebab-case), path, connect date
     (ISO), framework version at connection, status
     (`active`/`archived`); document that the manifest-init skill
     appends entries and that removed projects are marked
     `archived`, never deleted.
  Stop criterion: `llms.txt` lists all three files;
  `workflow/connected-projects.md` exists with the documented format
  and no entries yet.
  Maps to scenarios: entry after successful connection, archiving a
  project.

## 3. Verification

- [x] FR 3.1 Verify structure and registration

  Run `bash scripts/verify.sh` in the Manifest project — must pass;
  run `bash scripts/structure-parser.sh` on
  `workflow/temp-folder-rules.ru.md` — must exit 0 (agent-rules files
  are exempt from the parser by design). Run
  `openspec validate add-init-temp-and-commit-distribution --strict`
  (or plain validate if strict is unsupported).
  Stop criterion: verify.sh passes, parser exits 0, validate reports
  no errors.
  Maps to scenarios: clean reference file.
