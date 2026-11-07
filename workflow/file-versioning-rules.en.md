# File Versioning Rules

> **Status: draft**
> **Type: document**
> **Version: 1.0.0**
> **Updated: 2026-11-07**

# Description
Rules for versioning document files in a project connected to the
Manifest framework.

## 1. Version format

1.1. The version is a three-component number: `X.Y.Z`.

1.2. The version lives in the body, in the metadata block: `> **Version: X.Y.Z**`.

## 2. Version bumps

2.1. X (major) — breaking changes: a rule is removed or changed in meaning.

2.2. Y (minor) — new rules added, existing rules extended.

2.3. Z (patch) — clarifications, wording fixes, typos.

## 3. Version and status

3.1. `draft` — in development: no version bump required.

3.2. The version is bumped only for documents with status `approved`.

3.3. On every change of an `approved` document, the version is bumped by the change type (2.1–2.3).

3.4. The `draft` → `approved` transition does not change the version.

3.5. `archived` — the version is frozen; no further bumps.

## 4. Date

4.1. The date in the body, in the metadata block: `> **Updated: YYYY-MM-DD**`, is the date of the last change.

4.2. The date is updated on every change.

## 5. Initial version

5.1. A new document starts at `1.0.0`.