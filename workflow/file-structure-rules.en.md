1.# File Structure Rules
Description: heading reflecting the file content, located on line 1
2.# Metadata
Description: metadata block heading, located on line 3
3.> **Status: draft**
Description: metadata — status, located on line 5
4.> **Type: document**
Description: metadata — file type, located on line 6
5.> **Version: 1.0.0**
Description: metadata — version, located on line 7
6.> **Updated: 2026-11-07**
Description: metadata — date of last change, located on line 8
7.# Description
Description: description section heading, located on line 10
8.A short paragraph describing the document
Description: description text, located on line 11

## 1. Metadata block

* The metadata block is located in the header of the document, under the
  title. It is a group of blockquote lines:
  * `> **Status: draft**`
  * `> **Type: document**`
  * `> **Version: 1.0.0**`
  * `> **Updated: 2026-11-07**`
* The status line uses exactly one word: `**Status: draft**`. Nothing else
  is added to it.
* The status set (three base statuses, extensible):
  * `draft` — in development;
  * `approved` — approved;
  * `archived` — archived.
* `Version` is a three-component number `X.Y.Z`.
* `Updated` is the date of the last change, ISO `YYYY-MM-DD`.
* `Status` is the primary field. Versioning depends on the status and on
  the structure. The status list is defined here and is extensible.

Note: the structure document (this file) defines the list of statuses and
the location of the metadata block. The metadata change document defines
how each metadata field changes. Statuses and versions are described here,
not in the versioning rules.

## 2. Type

* `Type` selects the set of rules applied to the file.
* There are several types; the known value is `document`. The set is
  extensible.
* `document` — a Markdown document, subject to the full document structure
  (metadata block, Description section, section numbering, versioning,
  language suffix).

## 3. Section numbering

* Sections and subsections are numbered hierarchically, dot-separated, by
  depth: `1.` → `1.1.`, `1.2.` → `1.2.1.` (each level adds one component).

## 4. Labeled parts

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