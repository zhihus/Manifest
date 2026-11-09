# File Structure Rules

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-09**  

# Description
Universal structure rules for Markdown documents in a project
connected to the Manifest framework.

## 1. Exceptions for the structure rules file

### 1.1. Line description rule

```
Description:
Line descriptions according to the template are required only in
this file — for processing by algorithms. In other files line
descriptions are **NOT** placed.
```

### 1.2. Description in a code block

```
Description:
A line description is enclosed in a code block — this is not
present in other files.
```

### 1.3. Structure

```
Description:
The file is structured according to its own sections 2, 3, 4, 5, 6.
```

### 1.4. Region markup

```
Description:
Region markup (header/body/footer) and the `region` field are an
individual feature of this file: they are needed to make it clear
where what is. In other files the `region` field is not filled in.
```

## 2. General file structure rules

### 2.1. Markdown standard

```
Description:
File structure is built on the Markdown standard.
```

### 2.2. Line length
```
Description:
Each line of a file must not be longer than 100 characters.
The limit is controlled in the English (final) file; the Russian
file is a working reference, where length limits are not controlled.
```

### 2.3. Section numbering

```
Description:
Numbering applies only to the body and footer regions; it does not
extend to the header.
Sections and subsections are numbered hierarchically: 1. → 1.1. → 1.1.1.
Each level adds one component with a dot.
Numbering is continuous: the footer continues the body numbering
(## 1. → ## 2. Examples).
Level 1 (#) — header only: file title, # Metadata, # Description.
Level 2 (##) — body sections; cannot be a subsection.
Levels 3+ (###, ####) — subsections of a section (body or footer).
```

### 2.4. Universal line description format

```
Description:
purpose=<...>, line=<N>, required=<yes|no>,
  level=<...|—>, template=<...|—>, format=<...|—>,
  value kind=<free|one of the list|fixed|—>,
  values=<...|—>, length=<...|—>,
  count=<1|unlimited|—>, unicode symbol=<✅ | ❌ |—>,
  list=<extensible | fixed |—>,
  note=<...|—>, region=<header|body|footer|—>
Fields marked with "—" are skipped: the field does not apply to this line.
Unicode symbol: ✅ — correct, ❌ — incorrect.
```

### 2.5. Purpose

```
Description:
What the line represents (file title, status, version).
```

### 2.6. Number

```
Description:
Line number in the document.
```

### 2.7. Required

```
Description:
Whether the line is required: yes / no.
Requiredness is inherited: if a section is optional, all its
subsections are also optional. A required section may contain
optional subsections.
```

### 2.8. Hierarchy level

```
Description:
Headings only.
```

### 2.9. Template

```
Description:
Line pattern; <...> — placeholder value.
```

### 2.10. Format

```
Description:
Line format: ISO YYYY-MM-DD, X.Y.Z, —.
```

### 2.11. Value kind

```
Description:
Value kind: free, one of the list, fixed.
```

### 2.12. Length

```
Description:
Length recommendation: up to N words / up to M chars.
```

### 2.13. Count

```
Description:
How many such lines are allowed: 1, unlimited.
```

### 2.14. Unicode symbol

```
Description:
Unicode symbol in the line: ✅ — correct, ❌ — incorrect.
— — no symbol in the line.
```

### 2.15. Note

```
Description:
Additional context of the line that is not expressed by other
fields; — — no note.
```

### 2.16. Region

```
Description:
Document region: header, body, footer.
Header — file title, # Metadata, # Description and the description text.
Body — numbered sections.
Footer — the "Examples" section.
— — region not applicable.
```


## 3. Document header description

### 3.1. File title

```
Description:
purpose=file title, line=1, required=yes,
  level=1, template=<# <heading name>>, format=—,
  value kind=free, values=—,
  length=up to 5 words / up to 35 chars., count=1, unicode symbol=—,
  list=—, note=—, region=header
```

### 3.2. Metadata

```
Description:
purpose=metadata block, line=3, required=yes,
  level=1, template=<# Metadata>, format=—,
  value kind=fixed, values=Metadata, length=—,
  count=1, unicode symbol=—, list=—,
  note=—, region=header
Metadata value changes are described in the `file-metadata-change-rules.en.md` document.
```

### 3.3. Status

```
Description:
purpose=status, line=4, required=yes,
  level=—, template=<**Status: <value>**  >, format=—,
  value kind=one of the list, values=draft, approved, archived,
  length=—, count=1, unicode symbol=—,
  list=extensible, note=—, region=header
```

### 3.4. Type

```
Description:
purpose=file type, line=5, required=yes,
  level=—, template=<**Type: <value>**  >, format=—,
  value kind=one of the list, values=document,
  length=—, count=1, unicode symbol=—,
  list=extensible, note=—, region=header
```

### 3.5. Version

```
Description:
purpose=version, line=6, required=yes,
  level=—, template=<**Version: <value>**  >, format=X.Y.Z,
  value kind=free, values=—,
  length=—, count=1, unicode symbol=—, list=—,
  note=—, region=header
```

### 3.6. Date

```
Description:
purpose=date, line=7, required=yes,
  level=—, template=<**Updated: <value>**  >, format=ISO YYYY-MM-DD,
  value kind=free, values=—,
  length=—, count=1, unicode symbol=—, list=—,
  note=—, region=header
```

### 3.7. Description section

```
Description:
purpose=description section, line=9, required=yes,
  level=1, template=<# Description>, format=—,
  value kind=fixed, values=Description, length=—,
  count=1, unicode symbol=—, list=—,
  note=—, region=header
```

### 3.8. Description text

```
Description:
purpose=description, line=10, required=yes,
  level=—, template=—, format=—,
  value kind=free, values=—,
  length=up to 20 words / up to 100 chars., count=1, unicode symbol=—,
  list=—, note=—, region=header
```

## 4. Document body description

### 4.1. Single-line text field

```
Description:
purpose=heading with a rule, line=<N>, required=yes,
  level=2, template=<## <N>. <rule>>, format=—,
  value kind=free, values=—,
  length=up to 100 chars., count=unlimited,
  unicode symbol=—, list=—,
  note=the rule fits in one heading line;
  levels 3–4 are similar: ###, ####, region=body
```

### 4.2. Multi-line text field

```
Description:
purpose=text under a heading, line=<N>, required=yes,
  level=—, template=—, format=—,
  value kind=free, values=—,
  length=up to 50 words / up to 300 chars., count=unlimited,
  unicode symbol=—, list=—,
  note=the rule does not fit in one line;
  heading is short (2–3 words) with a number, region=body
```

## 5. Examples description

### 5.1. Examples section

```
Description:
purpose=section, line=<N>, required=no,
  level=2, template=<## <N>. Examples>, format=—,
  value kind=fixed, values=Examples, length=—,
  count=1, unicode symbol=—, list=—,
  note=—, region=footer
```

### 5.2. Subheading

```
Description:
purpose=subsection, line=<N>, required=no,
  level=3, template=<### <N>.<M>. <section name>>, format=—,
  value kind=free, values=—,
  length=up to 5 words / up to 35 chars., count=unlimited,
  unicode symbol=—, list=—,
  note=position is variable; groups examples by category,
  region=footer
```

### 5.3. Correct

```
Description:
purpose=example label, line=<N>, required=no,
  level=—, template=—, format=—,
  value kind=fixed, values=Correct, length=—,
  count=1, unicode symbol=—, list=—,
  note=required when examples are present; the examples section
  is optional, region=footer
```

### 5.4. Incorrect

```
Description:
purpose=example label, line=<N>, required=no,
  level=—, template=—, format=—,
  value kind=fixed, values=Incorrect, length=—,
  count=1, unicode symbol=—, list=—,
  note=—, region=footer
```

### 5.5. Example lines

```
Description:
purpose=example, line=<N>, required=no,
  level=—, template=<✅ | ❌ <example>>, format=—,
  value kind=free, values=—, length=—,
  count=unlimited, unicode symbol=✅ | ❌,
  list=—, note=—, region=footer
Example lines are bound to the nearest preceding label.
```

## 6. Examples

### 6.1. Correct

The correct example — the whole file `workflow/naming-rules.en.md`
in full, enclosed in a code block. The insertion is performed
when the structure file is approved (Status → approved).
No incorrect examples are provided.