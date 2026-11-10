# File Metadata Change Rules

# Metadata
> **Status: approved**  
> **Type: document**  
> **Version: 1.0.2**  
> **Updated: 2026-11-10**  

# Description
Rules for changing the metadata block of a document file in a project
connected to the Manifest framework.

## 1. Version

### 1.1. Version format

#### 1.1.1. The version is a three-component number: `X.Y.Z`.

### 1.2. Version bumps

#### 1.2.1. X (major) — breaking changes: existing content removed or changed in meaning.

#### 1.2.2. Y (minor) — new content added, existing content extended.

#### 1.2.3. Z (patch) — clarifications, wording fixes, typos.

### 1.3. Dependency on status

#### 1.3.1. A new document with status `draft` gets version `1.0.0`.

#### 1.3.2. The version is changed ONLY for a document with status `approved`.

#### 1.3.3. Status changes do not affect the version

The `draft` → `approved` or `approved` → `archived` status change does
not change the version.

## 2. Date

### 2.1. The date `> **Updated: YYYY-MM-DD**` is the date of the last change.

### 2.2. The date is updated on every change.

## 3. Type

### 3.1. The file type: `> **Type: document**`.

### 3.2. Rules for changing the type are not provided.

## 4. Status

### 4.1. The document status changes at the user's request.

### 4.2. Automatic status change is not provided.

### 4.3. The agent changes the status only where a process explicitly allows it.

### 4.4. The status value is one word from the list in `file-structure-rules.en.md`, sec. 3.3.

## 5. Examples

### 5.1. Correct

Correct

✅ The metadata block is in the header of this document.

### 5.2. Violation examples

Incorrect

❌ Status with extra text: `> **Status: draft**` (in development)

❌ Status with a value outside the list: `> **Status: in-development**`

❌ Version not in format: `> **Version: 1.0**`

❌ Date not in format: `> **Updated: 07.11.2026**`
