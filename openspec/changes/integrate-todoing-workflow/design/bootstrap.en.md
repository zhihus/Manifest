# Design — Store Bootstrap

## Purpose

Defines the procedure for initializing the Todoing store for the Manifest
project: installing the binary, generating the Project ID, writing the
configuration, and calling `store.init` with protection against overwrite.

## Boundaries

- Installing Todoing (the binary) is performed by the **user**. Manifest does
  not download, update, or install the Todoing binary.
- Manifest manages only: the Project ID, the `.todoing/config.toml`
  configuration, and the `store.init` call through the API.
- The bootstrap is not tied to `scripts/manifest-init.sh` until it is
  confirmed that this is the standard installation point for users, not dev
  infrastructure.

## Bootstrap procedure

1. **Check Todoing availability.** Manifest verifies that the `todoing`
   binary is on PATH and that `todoing api --json` responds. On
   unavailability — stop with diagnostics; installation is performed by the
   user separately.
2. **Project ID.** If `.manifest/project-id` is absent — generate a UUIDv4
   and write the file atomically. If the file exists — its value is used;
   when a store exists, it is reconciled with `store.info`.
3. **Configuration.** Manifest creates `.todoing/` and writes the
   recommended `config.toml` atomically only when the file is not yet
   present. An existing file is not overwritten: Manifest checks for the
   required statuses, outcome mapping, and transitions; on incompatibility it
   stops the bootstrap with diagnostics.
4. **store.init.** Manifest calls `store.init` with the Project ID from
   `.manifest/project-id`. The operation creates a new store only when the
   database does not exist.
5. **Verification.** Manifest verifies the result through `store.info` and
   `store.verify`.

## store.init behavior (confirmed from source)

- Creates `.todoing/` and a new database only when `todoing.db` does not
  exist.
- An existing database → error `store_already_initialized` (exit 6); no
  re-initialization is performed.
- Legacy Markdown tasks (`.todoing/tasks/*.md`) or `index.json` → error
  `migration_required` (exit 2); `store.migrate` is required, not
  `store.init`.
- An existing `config.toml` is validated and preserved; when absent, a
  generic default configuration is created by an atomic write (temp file +
  persist_noclobber).
- The Project ID from the envelope is used as-is; the CLI generates `p-<hex>`
  only when `--project-id` is absent, but JSON API calls must pass
  `project_id` in the envelope.

## Prohibitions

- Do not call `store.init` over an existing store or legacy Markdown data.
- Do not overwrite an existing `config.toml`.
- Do not download or update the Todoing binary.
- Do not perform automatic migration of legacy data in the MVP: a possible
  migration is a separate non-destructive procedure with a dry-run
  (`store.migrate --dry-run`) and user confirmation.

## Expected errors and their handling

| Error | Meaning | Manifest behavior |
|---|---|---|
| `store_already_initialized` | The database already exists | Reconcile the Project ID through `store.info`; on a match — continue, on a mismatch — stop with `project_id_mismatch` |
| `migration_required` | Legacy Markdown/index.json | Do not perform `store.init`; offer the user a separate migration procedure |
| `config_invalid` | Invalid config.toml | Stop the bootstrap; show diagnostics; do not overwrite the file |
| `project_id_mismatch` | The ID does not match the store metadata | Stop the integration; do not reinitialize the store |