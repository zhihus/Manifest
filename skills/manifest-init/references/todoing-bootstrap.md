# Todoing bootstrap contract

Todoing is user-managed. Manifest never downloads or updates its binary.

Use the JSON API as `todoing --json api`: pass exactly one JSON request on stdin and read exactly one JSON response from stdout.

## Binary resolution

Two usage modes are supported: a normal install on PATH, and a portable
package referenced by an explicit path. The resolver scripts
(`scripts/resolve-todoing.sh` / `scripts/resolve-todoing.py`) apply this
strict priority and verify the reported version before any store operation:

1. Explicit `TODOING_BIN` — must point to an existing file; a missing file is a hard stop.
2. Portable build in the Manifest release cache: `.todoing-cache/portable/<VERSION>/<PLATFORM>-<ARCH>/todoing[.exe]`.
3. `todoing` found on PATH.

An incompatible version is a hard stop: the resolver never silently falls back
to another binary. The release cache (`.todoing-cache/`) holds downloaded
releases separated by version and platform and is never mixed with the user
task store (`.todoing/`); it is git-ignored.

1. Require a resolvable todoing binary and a successful `todoing version` matching the required version (currently `1.2.0`).
   The full Manifest workflow requires a build from Todoing commit `653788a954d2a120db1beba854308982814d8222` or a verified descendant; the current public `main` branch lacks the required external-reference, Review, and final-commit API operations. Verify the binary's build provenance separately because `todoing version` may not report its source commit.
2. Inspect .todoing/ before writing. Existing database: never call store.init. Legacy .todoing/tasks/*.md or index.json: stop and request a separately approved migration. Existing config.toml: preserve and validate; never overwrite.
3. Project identity is .manifest/project-id. Existing store plus missing ID is a hard stop. For a new store, generate UUIDv4 and write atomically without clobbering.
4. Create .todoing/config.toml only if absent, only when no store or legacy data exists, using the Todoing contract in the workflow runbook.
5. Call store.init exactly once with the project ID only after all checks pass. Verify through store.info and store.verify.
6. After ambiguous/lost API responses, inspect actual state before retrying.
7. The Main Orchestrator coordinates Todoing API operations and retains the lock token. Role agents must follow the procedural boundary and must not independently call Todoing or receive the token. This is not technical isolation: the runtime does not block direct CLI/API access.
8. When both components are enabled, one Todoing task maps to one OpenSpec change; task title and openspec.change reference equal the change directory ID.
