# File Structure Rules

> **Status: draft**
> **Version: 1.0.0**
> **Updated: 2026-11-07**

# Description
Universal rules for the structure of Markdown documents in any project
connected to the Manifest framework.

## 1. Minimum structure

* Every Markdown file has a structure. Minimum: a title — a heading that
  starts with `#` — followed by a metadata block and a Description section.
* The Description section is a `# Description` heading followed by a short
  paragraph describing the document.

## 2. Metadata block

* The metadata block is a group of blockquote lines under the title:
  * `> **Status: draft**`
  * `> **Version: 1.0.0**`
  * `> **Updated: 2026-11-07**`
* The status line uses exactly one word: `**Status: draft**`. Nothing else
  is added to it.
* The fixed status set (three base statuses):
  * `draft` — in development;
  * `approved` — approved;
  * `archived` — archived.
* `Version` is a three-component number `X.Y.Z`.
* `Updated` is the date of the last change, ISO `YYYY-MM-DD`.

## 3. Section numbering

* Sections and subsections are numbered hierarchically, dot-separated, by
  depth: `1.` → `1.1.`, `1.2.` → `1.2.1.` (each level adds one component).