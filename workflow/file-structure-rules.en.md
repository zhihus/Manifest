# File Structure Rules

> **Status: draft**
> **Type: document**
> **Version: 1.0.0**
> **Updated: 2026-11-07**

# Description
Universal rules for the structure of Markdown documents in a project
connected to the Manifest framework.

## 1. Minimum structure

* Every Markdown file has a structure. Minimum: a title — a heading that
  starts with `#` — followed by a metadata block and a Description section.
* The Description section is a `# Description` heading followed by a short
  paragraph describing the document.

## 2. Metadata block

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

## 3. Type

* `Type` selects the set of rules applied to the file.
* There are several types; the known value is `document`. The set is
  extensible.
* `document` — a Markdown document, subject to the full document structure
  (metadata block, Description section, section numbering, versioning,
  language suffix).

## 4. Section numbering

* Sections and subsections are numbered hierarchically, dot-separated, by
  depth: `1.` → `1.1.`, `1.2.` → `1.2.1.` (each level adds one component).

## 5. Labeled parts

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