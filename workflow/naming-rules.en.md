# File and Directory Naming Rules

> **Status: draft**
> **Type: document**
> **Version: 1.0.0**
> **Updated: 2026-11-07**

# Description
Universal naming rules for files and directories in a project connected
to the Manifest framework.

## 1. Rules

### 1.1. Names in English only

### 1.2. kebab-case, lowercase, hyphen-separated, no spaces

### 1.3. A file name (not a directory name) always carries a language
suffix: `en`, or any other at the user's request.

## 2. Examples

### 2.1. Files — correct

✅ `naming-rules.en.md`
✅ `naming-rules.ru.md`

### 2.2. Files — incorrect

❌ `File Naming Rules.en.md`
❌ `fileNamingRules.en.md`
❌ `файл-именования.en.md`
❌ `naming-rules.md`
❌ `naming-rules.EN.md`

### 2.3. Directories — correct

✅ `workflow`
✅ `docs`
✅ `my-project`

### 2.4. Directories — incorrect

❌ `MyFolder`
❌ `my_folder`
❌ `папка`