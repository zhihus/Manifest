# Todoing bootstrap contract

Todoing is user-managed. Manifest never downloads or updates its binary.

Use the JSON API as `todoing --json api`: pass exactly one JSON request on stdin and read exactly one JSON response from stdout.

1. Require todoing in PATH and a successful todoing version.
   The full Manifest workflow requires a build from Todoing commit `6acca6087fbd4b39ad0dcd5f12db52dc4d84b163` or a verified descendant; the current public `main` branch lacks the required external-reference, Review, and final-commit API operations. Verify the binary's build provenance separately because `todoing version` may not report its source commit.
2. Inspect .todoing/ before writing. Existing database: never call store.init. Legacy .todoing/tasks/*.md or index.json: stop and request a separately approved migration. Existing config.toml: preserve and validate; never overwrite.
3. Project identity is .manifest/project-id. Existing store plus missing ID is a hard stop. For a new store, generate UUIDv4 and write atomically without clobbering.
4. Create .todoing/config.toml only if absent, only when no store or legacy data exists, using the Todoing contract in the workflow runbook.
5. Call store.init exactly once with the project ID only after all checks pass. Verify through store.info and store.verify.
6. After ambiguous/lost API responses, inspect actual state before retrying.
7. Only the Main Orchestrator calls Todoing API and owns the lock token. Subagents never receive the token or call Todoing.
8. When both components are enabled, one Todoing task maps to one OpenSpec change; task title and openspec.change reference equal the change directory ID.
