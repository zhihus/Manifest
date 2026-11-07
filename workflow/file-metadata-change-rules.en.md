# File Metadata Change Rules

> **Status: draft**
> **Type: document**
> **Version: 1.0.0**
> **Updated: 2026-11-07**

# Description
Rules for changing the metadata block of a document file in a project
connected to the Manifest framework.

## 1. Metadata

The metadata block of a document file consists of four fields:

> **Status: draft**
> **Type: document**
> **Version: 1.0.0**
> **Updated: 2026-11-07**

## 2. Version

2.1. The version is a three-component number: `X.Y.Z`.

2.2. The version is located in the document, in the header, in the metadata: > **Version: X.Y.Z**.

2.3. X (major) — breaking changes: existing content is removed or changed in meaning.

2.4. Y (minor) — new content added, existing content extended.

2.5. Z (patch) — clarifications, wording fixes, typos.

2.6. A new document with status `draft` gets version `1.0.0`.

2.7. A document with status `draft` does not change its version upon modification.

2.8. The version changes only for documents with status `approved`.

2.9. The `draft` → `approved` or `approved` → `archived` status change does not change the version.

2.10. With status `archived` any version change is forbidden.

## 3. Date

3.1. The date in the metadata block: `> **Updated: YYYY-MM-DD**`, is the date of the last change.

3.2. The date is updated on every change.

## 4. Type

4.1. The file type is indicated in the metadata: `> **Type: document**`.

## 5. Status

5.1. The document status is indicated in the metadata: `> **Status: draft**`, `> **Status: approved**`, or `> **Status: archived**`.