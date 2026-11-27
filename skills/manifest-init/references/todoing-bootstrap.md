# Todoing bootstrap contract

Todoing is user-managed. Manifest never downloads or updates its binary.

1. Require todoing in PATH and a successful todoing version.
2. Inspect .todoing/ before writing. Existing database: never call store.init. Legacy .todoing/tasks/*.md or index.json: stop and request a separately approved migration. Existing config.toml: preserve and validate; never overwrite.
3. Project identity is .manifest/project-id. Existing store plus missing ID is a hard stop. For a new store, generate UUIDv4 and write atomically without clobbering.
4. Create .todoing/config.toml only if absent, only when no store or legacy data exists, using the Todoing contract in the workflow runbook.
5. Call store.init exactly once with the project ID only after all checks pass. Verify through store.info and store.verify.
6. After ambiguous/lost API responses, inspect actual state before retrying.
7. Only the Main Orchestrator calls Todoing API and owns the lock token. Subagents never receive the token or call Todoing.
8. When both components are enabled, one Todoing task maps to one OpenSpec change; task title and openspec.change reference equal the change directory ID.
