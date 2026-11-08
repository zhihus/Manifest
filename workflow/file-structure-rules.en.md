1.# File Structure Rules
Description: heading, file title, level 1, line 1, length recommendation: up to 5 words, up to 35 characters; value: <title>
2.# Metadata
Description: heading, of the metadata block, level 1, line 3; value: Metadata
Metadata value changes are described in the `file-metadata-change-rules.en.md` document.
3.> **Status: draft**
Description: metadata, status, line 5, template: > **<name>: <value>** ; value: one of the list
Status list: draft — in development, approved — approved, archived — archived
4.> **Type: document**
Description: metadata, file type, line 6, template: > **<name>: <value>** ; value: one of the list
Type list: document — Markdown document
5.> **Version: 1.0.0**
Description: metadata, version, line 7, template: > **<name>: <value>** ; value: three-component number X.Y.Z, where X — major, Y — minor, Z — patch
6.> **Updated: 2026-11-07**
Description: metadata, date, line 8, template: > **<name>: <value>** ; value: date in ISO format YYYY-MM-DD
7.# Description
Description: heading, of the description section, level 1, line 10; value: Description
8.A short paragraph describing the document
Description: text, description, line 11, length recommendation: up to 20 words, up to 100 characters

# Description
Structure rules for Markdown documents in a project connected to the Manifest framework.

## 1. Type

* `Type` selects the set of rules applied to the file.
* There are several types; the known value is `document`. The set is
  extensible.
* `document` — a Markdown document, subject to the full document structure
  (metadata block, Description section, section numbering, versioning,
  language suffix).

## 2. Section numbering

* Sections and subsections are numbered hierarchically, dot-separated, by
  depth: `1.` → `1.1.`, `1.2.` → `1.2.1.` (each level adds one component).

## 3. Labeled parts

* When a section contains multiple labeled parts (e.g. correct / incorrect
  examples), the labels are standalone text lines under a single section
  heading — not separate sub-headings with the label embedded in the
  heading text.

  Correct:

  ```
  ### 2.1. Files

  Correct

  ✅ `naming-rules.en.md`
  ✅ `naming-rules.ru.md`

  Incorrect

  ❌ `File Naming Rules.en.md`
  ❌ `fileNamingRules.en.md`
  ```

  Incorrect:

  ```
  ### 2.1. Files — correct

  ✅ `naming-rules.en.md`
  ✅ `naming-rules.ru.md`

  ### 2.2. Files — incorrect

  ❌ `File Naming Rules.en.md`
  ❌ `fileNamingRules.en.md`
  ```