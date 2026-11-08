```
1.# <heading name>
Description: heading, file title, level 1, line 1, length recommendation: up to 5 words, up to 35 characters; template: <# <heading name>>
2.# Metadata
Description: heading, of the metadata block, level 1, line 3; template: <# <metadata name>>; <metadata name> = "Metadata".
Metadata value changes are described in the `file-metadata-change-rules.en.md` document.
3.> **Status: draft**
Description: metadata, status, line 5, template: > **<name>: <value>** ; value: one of the list
Value list (extensible): draft — in development, approved — approved, archived — archived
4.> **Type: document**
Description: metadata, file type, line 6, template: > **<name>: <value>** ; value: one of the list
Value list (extensible): document — Markdown document
5.> **Version: 1.0.0**
Description: metadata, version, line 7, template: > **<name>: <value>** ; value: three-component number X.Y.Z, where X — major, Y — minor, Z — patch
6.> **Updated: 2026-11-07**
Description: metadata, date, line 8, template: > **<name>: <value>** ; value: date in ISO format YYYY-MM-DD
7.# Description
Description: heading, of the description section, level 1, line 10; template: <# <description name>>; <description name> = "Description".
Structure rules for Markdown documents in a project connected to the Manifest framework.
8.A short paragraph describing the essence of the document
Description: text, description, line 11, length recommendation: up to 20 words, up to 100 characters
9.## 1. <section title>
Description: heading, section, level 2, line 13, length recommendation: up to 5 words, up to 35 characters; value: <section title>
```

## 1. Section numbering

* Sections and subsections are numbered hierarchically, dot-separated, by
  depth: `1.` → `1.1.`, `1.2.` → `1.2.1.` (each level adds one component).

## 2. Labeled parts

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