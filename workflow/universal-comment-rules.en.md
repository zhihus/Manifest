# Universal Script Commenting Rules

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-12**

# Description
Universal comment rules for scripts in a project connected to the
Manifest framework.

## 1. Rules

### 1.1. Header comment block: fields in exact order, comma‑separated, each with `=`.

Skip a field with `—` when it does not apply.

```
purpose=<...>, line=<N>, required=<yes|no>, level=<...|—>,
  template=<...|—>, format=<...|—>, value kind=<free|one of the list|fixed|—>,
  values=<...|—>, length=<...|—>, count=<1|unlimited|—>,
  unicode symbol=<✅ | ❌ |—>, list=<extensible | fixed |—>,
  note=<...|—>, region=<header|body|footer|—>
```

### 1.2. LLM tags: `# LLM: TEST:`, `# LLM: EXPECTED:`, `# LLM: FUNCTION:`, `# LLM: NOTE:`, `# LLM: EXAMPLE:`.

TEST — brief test description, up to 60 chars. EXPECTED — expected
result, concise. FUNCTION — purpose, parameters, returns, example.
NOTE — short note, up to 80 chars. EXAMPLE — short usage snippet,
up to 120 chars, prefixed with the correctness symbol.

### 1.3. Logging prints `timestamp | message`; INFO to STDOUT, ERROR to STDERR.

Define `log()` before first use. Exit codes: 0 — success,
1 — configuration error, 2 — runtime error.

### 1.4. File names in kebab‑case, lowercase, hyphens only, with a language suffix.

No spaces, uppercase, or underscores. Directory names follow the
same rules, without a language suffix.

## 2. Examples

### 2.1. Header comment block

Correct

✅ `<# purpose=script entry point, line=1, required=yes, level=1, template=<# Script: <name> #>, format=—, value kind=—, values=—, length=—, count=1, unicode symbol=✅, list=—, note=—, region=header #>`

Incorrect

❌ `purpose=line, required=yes` — missing fields, wrong order, no block comment

### 2.2. LLM tags

Correct

✅ `# LLM: EXAMPLE: ✅ ./script.ps1 arg1 arg2`
✅ `# LLM: NOTE: retry up to 3 times`

Incorrect

❌ `# EXAMPLE: ./script.ps1 arg1 arg2` — no `LLM:` prefix
❌ `# LLM: EXAMPLE: ./script.ps1 arg1 arg2` — no correctness symbol

### 2.3. File naming

Correct

✅ `script.en.ps1`
✅ `run-tests.ru.bat`

Incorrect

❌ `Script_En.ps1`
❌ `run tests.ps1`
❌ `script.ps1` — no language suffix