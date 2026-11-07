# File Metadata Change Rules

> **Status: draft**
> **Type: document**
> **Version: 1.0.0**
> **Updated: 2026-11-07**

# Description
Rules for changing the metadata block of a document file in a project
connected to the Manifest framework.

## 1. Metadata

Metadata: version, date, file type, and status are located in the
document header.

> **Status: draft**
> **Type: document**
> **Version: 1.0.0**
> **Updated: 2026-11-07**

## 2. Version

### 2.1. Format

2.1.1. The version is a three-component number: `X.Y.Z`.

### 2.2. Bumps

2.2.1. X (major) — breaking changes: existing content is removed or changed in meaning.

2.2.2. Y (minor) — new content added, existing content extended.

2.2.3. Z (patch) — clarifications, wording fixes, typos.

### 2.3. Status

2.3.1. A new document with status `draft` gets version `1.0.0`.

2.3.2. A document with status `draft` does not change its version upon modification.

2.3.3. The version changes only for documents with status `approved`.

2.3.4. The `draft` → `approved` or `approved` → `archived` status change does not change the version.

2.3.5. With status `archived` any version change is forbidden.

## 3. Date

3.1. The date `> **Updated: YYYY-MM-DD**` is the date of the last change.

3.2. The date is updated on every change.

## 4. Type

4.1. The file type: `> **Type: document**`.

## 5. Status

5.1. The document status: `> **Status: draft**`, `> **Status: approved**`, or `> **Status: archived**`.