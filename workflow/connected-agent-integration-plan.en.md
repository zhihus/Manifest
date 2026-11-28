# Connected Agent Integration Plan

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.1.0**  
> **Updated: 2026-11-28**

# Description
One-run setup of Manifest, OpenSpec, and Todoing guidance in a consumer project.

## Execute in one run

1. **Audit.** Record project root, branch, HEAD, and Git status. Read AGENTS.md,
   navigation, .llmignore, and publication rules. Verify manifest.yaml,
   checksum, format_version, switches, OpenSpec, Todoing, Project ID, config,
   and store. Use read/verify operations only on an existing database.

2. **Mode.** OpenSpec is enabled by default for a new consumer connection; do not treat
   an existing `enabled: false` as user opt-out. During onboarding, enable it
   using the actual Manifest schema and recalculate the checksum with the
   supported method. Disable it only on the user's explicit decision. Todoing
   is also required for coordinated mode. Stop on unknown schema, inability to
   enable OpenSpec, damaged store, uncertain binary provenance, or conflicting
   project rules.

3. **Agent context.** Create a concise consumer-specific guide based on
   `workflow/connected-agent-onboarding.ru.md`. Retain artifact-creation rules,
   change/task mapping, authority, lifecycle, and normative references.
   Do not copy irrelevant Manifest internals or include customer data, local
   paths, or secrets.

4. **Entry points.** Link the guide from AGENTS.md and the project navigation.
   Ensure .llmignore permits access. Do not replace existing rules wholesale.

5. **Readiness.** Verify that the agent understands switches/mode, when to create
   changes/tasks, the one-change/one-task rule in coordinated mode, FR storage
   in tasks.md, authority, `backlog → ready`, Review, and recovery. Use read-only
   checks; create no tasks, changes, test records, or commits.

## Constraints

Do not change business logic or user data; recreate no Todoing store; preserve
uncommitted files and Git history. Keep local configs, databases, and customer
material out of publication. Do not commit, push, open PRs, merge, delete
branches/worktrees, or modify Manifest core. Stop and ask if publication rules
conflict with required work.

## Completion and report

Complete when config/checksum are valid, enabled components are available,
the agent discovers the required guide, OpenSpec ↔ Todoing rules match their
contracts, user data is preserved, and nothing was created or published.

Report changed files, switches before/after, checks, and limitations; confirm
no tasks/changes, commits, or remote changes were created.
