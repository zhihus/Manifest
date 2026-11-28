# Connected Agent Context Setup Plan

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-28**  

# Description
A single-run plan for connecting Manifest, OpenSpec, and Todoing guidance to a consumer project's agent.

## 1. Goal

Ensure that an agent in a connected project discovers Manifest capabilities,
understands when to create specifications and tasks, maintains their relationship,
and follows the coordinated workflow.

The plan is executed in one agent run. It does not create user tasks or implement
product changes.

## 2. Sources and boundaries

The normative agent guidance is
`workflow/connected-agent-onboarding.ru.md` and its English translation.
Detailed procedures are defined by `workflow/README.en.md`,
`docs/architecture/todoing-contract.ru.md`, OpenSpec rules, and the contract
for the actual Manifest version.

The consumer remains an independent project. The agent must respect its AGENTS.md,
.llmignore, publication rules, documentation language, and local architecture.
Do not copy Manifest development scripts into the consumer or adapt the Manifest
core to a consumer-specific project.

## 3. Single-run execution

### 3.1. Audit

1. Identify the consumer root, active branch, HEAD, and Git state.
2. Read AGENTS.md, llms/navigation map, .llmignore, and publication rules.
3. Verify .manifest/manifest.yaml, checksum, format_version, and the actual
   switch schema.
4. Check OpenSpec and Todoing availability, Project ID, config, and store.
   For an existing Todoing store, use safe read/verify operations only.
5. Record which components are enabled and which instructions the agent receives
   at startup.

### 3.2. Component configuration

1. Compare the current configuration with the user's intent to use specifications
   and tasks together.
2. If OpenSpec is disabled while the user has authorized the coordinated workflow,
   enable it only through the confirmed key in the actual Manifest schema and
   recalculate the checksum using the supported method.
3. Enable Todoing only when a valid binary, Project ID, config, and verified store
   are available. Never reinitialize an existing database or change its config
   without need.
4. Do not change unrelated switches or enable optional checks automatically.
5. Stop and report if the schema is incompatible, the store is damaged, binary
   provenance is uncertain, or project rules conflict with the required setup.

### 3.3. Transfer agent context

1. Create a dedicated consumer-project document based on
   `workflow/connected-agent-onboarding.ru.md`. Keep only applicable rules;
   do not copy Manifest internals that the consumer does not need.
2. Follow the consumer project's documentation language and format. Do not put
   customer information, local paths, secrets, or private data in universal or
   publishable documents.
3. Add a mandatory link to the new document from AGENTS.md at the agent entry point.
4. Add a link to llms.txt or the equivalent navigation map, if present.
5. Ensure .llmignore does not exclude the document, or provide explicit read access.
6. Preserve links to normative Manifest, OpenSpec, and Todoing documents. Prefer
   precise links over copying large specifications.

### 3.4. Readiness verification

Verify that the agent can determine unambiguously at startup:

- whether the project is connected to Manifest and its configuration is valid;
- whether OpenSpec and Todoing are enabled and which integration mode applies;
- when an OpenSpec change is required and when no formal specification is needed;
- that one OpenSpec change maps to one Todoing task only in coordinated mode;
- that FRs and decomposition remain in tasks.md;
- who creates and updates Todoing tasks and who controls statuses and locks;
- that `backlog → ready` requires an explicit user decision;
- how independent Review, completion, archiving, and recovery work.

Use instruction analysis and safe read-only commands. Do not create Todoing tasks,
OpenSpec changes, test records, or commits.

## 4. Preservation and publication

- Do not change business logic, source code, or user data.
- Do not delete or recreate the SQLite store.
- Preserve existing instructions and user changes; make minimal edits.
- Keep local configs, databases, and customer material out of publication diffs.
- Do not commit, push, open a PR, merge, or publish.
- Do not delete worktrees or branches.
- Stop and ask the user if a required change affects the public product or
  conflicts with publication policy.

## 5. Completion criteria

The plan is complete when:

1. Manifest configuration is valid, checksum matches, and switches reflect the
   authorized mode.
2. OpenSpec and Todoing are available within the enabled components.
3. The agent receives mandatory guidance through AGENTS.md and the navigation map.
4. OpenSpec ↔ Todoing mapping is unambiguous and consistent with normative contracts.
5. User files, Git history, and Todoing store are preserved.
6. No tasks or OpenSpec changes were created; no commits or remote changes occurred.

The report must list changed files, switches before/after, checks, remaining
limitations, and confirm that no tasks were created and the remote repository
was not changed.
