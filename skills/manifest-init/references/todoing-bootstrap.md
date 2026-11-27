# Todoing bootstrap contract

Todoing is user-managed. Manifest never downloads or updates its binary.

Use the JSON API as `todoing --json api`: pass exactly one JSON request on stdin and read exactly one JSON response from stdout.

## Binary resolution

Resolve the Todoing executable using only these sources:

1. If `TODOING_BIN` is set, it must point to an existing file. If the path is invalid, stop; do not fall back to another binary.
2. Otherwise, resolve `todoing` from the connected project's `PATH`. If it is unavailable, stop and ask the user to install Todoing or configure `TODOING_BIN`.

Do not depend on Manifest development scripts, resolver scripts, a Manifest release cache, or automatic binary downloads. Connected projects do not receive the Manifest repository's `scripts/` directory.

After resolving the executable, require a successful `todoing version` matching the required version (currently `1.2.0`). An incompatible version is a hard stop; do not silently fall back to another binary.

The full Manifest workflow requires a build from Todoing commit `653788a954d2a120db1beba854308982814d8222` or a verified descendant; the current public `main` branch lacks the required external-reference, Review, and final-commit API operations. Verify the binary's build provenance separately because `todoing version` may not report its source commit.

## Store bootstrap

1. Inspect .todoing/ before writing. Existing database: never call store.init. Legacy .todoing/tasks/*.md or index.json: stop and request a separately approved migration. Existing config.toml: preserve and validate; never overwrite.
2. Project identity is .manifest/project-id. Existing store plus missing ID is a hard stop. For a new store, generate UUIDv4 and write atomically without clobbering.
3. Create .todoing/config.toml only if absent, only when no store or legacy data exists, using the Todoing contract in the workflow runbook.
4. Call store.init exactly once with the project ID only after all checks pass. Verify through store.info and store.verify.
5. After ambiguous/lost API responses, inspect actual state before retrying.
6. The Main Orchestrator coordinates Todoing API operations and retains the lock token. Role agents must follow the procedural boundary and must not independently call Todoing or receive the token. This is not technical isolation: the runtime does not block direct CLI/API access.
7. When both components are enabled, one Todoing task maps to one OpenSpec change; task title and openspec.change reference equal the change directory ID.
