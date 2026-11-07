# File Metadata Change Rules

> **Status: draft**
> **Type: document**
> **Version: 1.0.0**
> **Updated: 2026-11-07**

# Description
Rules for changing the metadata block of a document file in a project
connected to the Manifest framework.

## 1. Metadata

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

2.3.2. The version is changed ONLY for a document with status `approved`.

2.3.3. The `draft` → `approved` or `approved` → `archived` status change does not change the version.

## 3. Date

3.1. The date `> **Updated: YYYY-MM-DD**` is the date of the last change.

3.2. The date is updated on every change.

## 4. Type

4.1. The file type: `> **Type: document**`.

4.2. Rules for changing the type are not provided.

## 5. Status

5.1. The document status changes at the user's request.

5.2. Automatic status change is not provided.

## 6. Examples

### 6.1. Correct

The correct metadata block is in the header of this document.

### 6.2. Incorrect

❌ Status with extra text: `> **Status: draft**` (in development)

❌ Status with a value outside the list: `> **Status: in-development**`

❌ Version not in format: `> **Version: 1.0**`

❌ Date not in format: `> **Updated: 07.11.2026**`