# Design

## Decisions

1. **temp/ delivery — two channels.** Primary: the boilerplate block is
   wired directly into subagent definitions (`C:/Users/<user>/.zcode/agents/*.md`),
   so the rule is present in every subagent prompt without the main
   agent having to remember it. Secondary: a section in the project
   agent file for agents that do read project context files.
   Source of the text: one boilerplate block in
   `workflow/temp-folder-rules.ru.md`.
2. **Agent file structure.** `agent-rules` does NOT follow
   `file-structure-rules` — that structure applies to rule files in
   `workflow/` only. The agent file is modeled on
   `docs/templates/agents.template.md`: plain sections, no metadata
   header, no Examples footer. The structure parser is not applied to
   it. First release is minimal; the user adjusts the file manually
   afterwards.
3. **Preserved-content block.** A marked block in `agent-rules` holds
   rules transferred from the project's original agent file during
   archive-based replacement. It is not titled "temporary"; it is
   framed by machine-readable markers
   (`<!-- manifest:preserved start -->` / `<!-- manifest:preserved end -->`).
   The parser can recognize the frame as one block; the marker tells
   the agent the content came from the project. Semantics are
   documented in the agent file rule.
4. **Transfer rule.** On archive-based replacement only the substance
   is transferred into the preserved block: the rules the model must
   follow. The original file's structure (header, fields, footer,
   service elements) is cut away.
5. **Archive location.** Replaced originals go to
   `.manifest/archive/<YYYY-MM-DD-HHMMSS>/` — inside the connection
   marker, clearly framework-owned, nothing lost. Merging/appending
   into existing files is rejected: hard to produce, hard to parse.
6. **Registry.** `workflow/connected-projects.md` in the Manifest
   project; one entry per project: name (kebab-case), path, connect
   date (ISO), framework version at connection, status
   (`active`/`archived`). The manifest-init skill (the agent running
   it, not the script) appends the entry on success; if the Manifest
   project is not found, the agent reports it and continues without
   writing.
7. **Distribution.** `skills/manifest-init/dist/` is self-contained:
   `init.sh` copies only from its own folder; `MANIFEST_ROOT` is
   removed. Syncing framework files into `dist/` + writing `VERSION`
   is a release step in the Manifest project.
8. **dist exclusions (roadmap §1.6).** `dist/` must not contain the
   Manifest's own dev infrastructure `scripts/verify.sh` and
   `scripts/hooks/` — acceptance scenario.
9. **Language workflow.** RU drafts first (`*.ru.md`), user approves,
   then EN finals (≤100 chars/line) per project AGENTS.md rules.

## Risks

- User-level agent definitions are outside the repository — the
  Manifest change documents the edit, the file itself is not
  version-controlled here.
- The preserved-block marker needs parser support later; for now the
  marker is prose-documented, not validated.
