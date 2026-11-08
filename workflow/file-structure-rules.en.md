# File Structure Rules

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-08**

# Description
Universal structure rules for Markdown documents in a project
connected to the Manifest framework.

## 1. General file structure rules

### 1.1. Line length
Each line of a file must not be longer than 100 characters.

### 1.2. Line description format

```
Description: type=<...>, purpose=<...>, line=<N>, required=<yes|no>,
  level=<...|—>, template=<...|—>, value=<...|—>, length=<...|—>
```

### 1.3. Type

```
The line kind: heading, metadata, text.
```

### 1.4. Purpose

```
What the line represents (file title, status, version).
```

### 1.5. Line

```
Line number in the real document.
```

### 1.6. Required

```
Whether the line is required in the document: yes / no.
```

### 1.7. Level

```
Hierarchy level (headings only; otherwise —).
```

### 1.8. Template

```
Line pattern; <...> — placeholder value; otherwise —.
```

### 1.9. Value

```
Allowed value: free, one of the list, fixed; otherwise —.
```

### 1.10. Length

```
Length recommendation: up to N words / up to M chars; otherwise —.
Skip marker: — (field not applicable to this line).
```

### 1.11. Rules for this file only

```
This file is the root: other files are filled according to its rules.
The unique rules below apply only to this file.

Transcription format: each line of the target document is shown first,
followed by an `Description:` annotation line. This format is used only
in this file.
```

## 2. Document header description

### 2.1. File title

```
# <heading name>
Description: type=heading, purpose=file title, line=1, required=yes,
  level=1, template=# <heading name>, value=free, length=up to 5 words / up to 35 chars.
```

### 2.2. Metadata block

```
# Metadata
Description: type=heading, purpose=metadata block, line=3, required=yes,
  level=1, template=# <metadata name>, value=Metadata, length=—
Metadata value changes are described in the `file-metadata-change-rules.en.md` document.
```

### 2.3. Status

```
> **Status: draft**
Description: type=metadata, purpose=status, line=5, required=yes,
  level=—, template=> **<name>: <value>**, value=one of the list, length=—
Value list (extensible): draft — in development, approved — approved, archived — archived
```

### 2.4. Type

```
> **Type: document**
Description: type=metadata, purpose=file type, line=6, required=yes,
  level=—, template=> **<name>: <value>**, value=one of the list, length=—
Value list (extensible): document — Markdown document
```

### 2.5. Version

```
> **Version: 1.0.0**
Description: type=metadata, purpose=version, line=7, required=yes,
  level=—, template=> **<name>: <value>**, value=X.Y.Z, length=—
```

### 2.6. Date

```
> **Updated: 2026-11-07**
Description: type=metadata, purpose=date, line=8, required=yes,
  level=—, template=> **<name>: <value>**, value=ISO YYYY-MM-DD, length=—
```

### 2.7. Description section

```
# Description
Description: type=heading, purpose=description section, line=10, required=yes,
  level=1, template=# <description name>, value=Description, length=—
Structure rules for Markdown documents in a project connected to the Manifest framework.
```

### 2.8. Description text

```
A short paragraph describing the essence of the document
Description: type=text, purpose=description, line=11, required=no,
  level=—, template=—, value=free, length=up to 20 words / up to 100 chars.
```

### 2.9. Section heading

```
## 1. <section title>
Description: type=heading, purpose=section, line=13, required=yes,
  level=2, template=## <section title>, value=free, length=up to 5 words / up to 35 chars.
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

# 3. Examples

3.1. Files

Correct

Incorrect