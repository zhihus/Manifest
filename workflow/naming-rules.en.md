# File and Directory Naming Rules

> **Status: approved**
> **Type: document**
> **Version: 1.0.0**
> **Updated: 2026-11-07**

# Description
Universal naming rules for files and directories in a project connected
to the Manifest framework.

## 1. Rules

1.1. Names in English only.

1.2. kebab-case, lowercase, hyphen-separated, no spaces.

1.3. A file name (not a directory name) always carries a language
    suffix: `en`, or any other at the user's request.

## 2. Examples

2.1. Files

Correct

✅ `naming-rules.en.md`
✅ `naming-rules.ru.md`

Incorrect

❌ `File Naming Rules.en.md`
❌ `fileNamingRules.en.md`
❌ `файл-именования.en.md`
❌ `naming-rules.md`
❌ `naming-rules.EN.md`

2.2. Directories

Correct

✅ `workflow`
✅ `docs`
✅ `my-project`

Incorrect

❌ `MyFolder`
❌ `my_folder`
❌ `папка`