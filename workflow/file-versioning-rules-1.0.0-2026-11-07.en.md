# File Versioning Rules

> **Status: draft**

Rules for versioning document files in any project connected to the
Manifest framework.

## 1. Version format

### 1.1. The version is a three-component number: `X.Y.Z`.

### 1.2. The version lives in the file name: `<name>-<version>-<date>.<lang>.md`.

## 2. Version bumps

### 2.1. X (major) — breaking changes: a rule is removed or changed in meaning.

### 2.2. Y (minor) — new rules added, existing rules extended.

### 2.3. Z (patch) — clarifications, wording fixes, typos.

## 3. Date

### 3.1. The date in the file name is the date of the last change, ISO `YYYY-MM-DD`.

### 3.2. The date is updated on every version bump.

## 4. Initial version

### 4.1. A new document starts at `1.0.0`.