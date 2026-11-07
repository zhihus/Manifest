# File Structure Rules

> **Status: draft**

Universal rules for the structure of Markdown documents in any project
connected to the Manifest framework.

## 1. Minimum structure

* Every Markdown file has a structure. Minimum: a title — a heading that
  starts with `#` — followed by a status line.

## 2. Status line

* The status line uses exactly one word: `**Status: draft**`. Nothing else
  is added to it.
* The fixed status set (three base statuses):
  * `draft` — in development;
  * `approved` — approved;
  * `archived` — archived.

## 3. Section numbering

* Sections and subsections are numbered hierarchically, dot-separated, by
  depth: `1.` → `1.1.`, `1.2.` → `1.2.1.` (each level adds one component).