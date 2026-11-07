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

1.2. The version is located in the document, in the header, in the metadata: > **Version: X.Y.Z**.

## 2. Version bumps

2.1. X (major) — breaking changes: existing content is removed or changed in meaning.

2.2. Y (minor) — new content added, existing content extended.

2.3. Z (patch) — clarifications, wording fixes, typos.

## 3. Version and status

3.1. A new document with status `draft` gets version `1.0.0`.

3.2. A document with status `draft` does not change its version upon modification.

3.3. The version changes only for documents with status `approved`.

3.4. The `draft` → `approved` transition does not change the version.

3.5. With status `archived` — the version is frozen; version bump is forbidden.

## 4. Date

4.1. The date in the body, in the metadata block: `> **Updated: YYYY-MM-DD**`, is the date of the last change.

4.2. The date is updated on every change.