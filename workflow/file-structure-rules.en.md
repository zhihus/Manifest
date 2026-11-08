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
1.1. Each line of a file must not be longer than 100 characters.

1.2. Line description format (universal template):

```
Description: type=<...>, purpose=<...>, line=<N>, required=<yes|no>,
  level=<...|—>, template=<...|—>, value=<...|—>, length=<...|—>
```

Template fields:
- `type` — line kind: heading, metadata, text.
- `purpose` — what the line represents (file title, status, version).
- `line` — line number in the real document.
- `required` — whether the line is required in the document: yes / no.
- `level` — hierarchy level (headings only; otherwise —).
- `template` — line pattern; <...> — placeholder value; otherwise —.
- `value` — allowed value: free, one of the list, fixed; otherwise —.
- `length` — length recommendation: up to N words / up to M chars; otherwise —.
Skip marker: — (field not applicable to this line).

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