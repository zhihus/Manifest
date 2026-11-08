# File Structure Rules

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-08**

# Description
Universal structure rules for Markdown documents in a project
connected to the Manifest framework.

## 1. Rules for this file only

### 1.1. Line description rule

```
Under each line, a line description is required according to the template.
```

## 2. General file structure rules

### 2.1. Line length
Each line of a file must not be longer than 100 characters.

### 2.2. Universal line description format

```
Description: type=<...>, purpose=<...>, line=<N>, required=<yes|no>,
  level=<...|—>, template=<...|—>, value=<...|—>, length=<...|—>
Fields marked with "—" are skipped: the field does not apply to this line.
```

### 2.3. Type

```
The line kind: heading, metadata, text.
```

### 2.4. Purpose

```
What the line represents (file title, status, version).
```

### 2.5. Line

```
Line number in the real document.
```

### 2.6. Required

```
Whether the line is required in the document: yes / no.
```

### 2.7. Level

```
Hierarchy level (headings only; otherwise —).
```

### 2.8. Template

```
Line pattern; <...> — placeholder value; otherwise —.
```

### 2.9. Value

```
Allowed value: free, one of the list, fixed; otherwise —.
```

### 2.10. Length

```
Length recommendation: up to N words / up to M chars; otherwise —.
```


## 3. Document header description

### 3.1. File title

```
# <heading name>
Description: type=heading, purpose=file title, line=1, required=yes,
  level=1, template=# <heading name>, value=free, length=up to 5 words / up to 35 chars.
```

### 3.2. Metadata block

```
# Metadata
Description: type=heading, purpose=metadata block, line=3, required=yes,
  level=1, template=# <metadata name>, value=Metadata, length=—
Metadata value changes are described in the `file-metadata-change-rules.en.md` document.
```

### 3.3. Status

```
> **Status: draft**
Description: type=metadata, purpose=status, line=5, required=yes,
  level=—, template=> **<name>: <value>**, value=one of the list, length=—
Value list (extensible): draft — in development, approved — approved, archived — archived
```

### 3.4. Type

```
> **Type: document**
Description: type=metadata, purpose=file type, line=6, required=yes,
  level=—, template=> **<name>: <value>**, value=one of the list, length=—
Value list (extensible): document — Markdown document
```

### 3.5. Version

```
> **Version: 1.0.0**
Description: type=metadata, purpose=version, line=7, required=yes,
  level=—, template=> **<name>: <value>**, value=X.Y.Z, length=—
```

### 3.6. Date

```
> **Updated: 2026-11-07**
Description: type=metadata, purpose=date, line=8, required=yes,
  level=—, template=> **<name>: <value>**, value=ISO YYYY-MM-DD, length=—
```

### 3.7. Description section

```
# Description
Description: type=heading, purpose=description section, line=10, required=yes,
  level=1, template=# <description name>, value=Description, length=—
Structure rules for Markdown documents in a project connected to the Manifest framework.
```

### 3.8. Description text

```
A short paragraph describing the essence of the document
Description: type=text, purpose=description, line=11, required=no,
  level=—, template=—, value=free, length=up to 20 words / up to 100 chars.
```

### 3.9. Section heading

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