# Commit Message Rules

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-09**  

# Description
Universal commit message rules for a project connected to the Manifest
framework.

## 1. Message format

### 1.1. Format: `<type>(<scope>): <subject>`.

### 1.2. Subject

English, imperative mood, lowercase, singular, no trailing period;
target length up to 50 characters, not a hard limit.

### 1.3. Type list

`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`,
`ci`, `chore`, `revert`.

### 1.4. Scope

An optional short stable identifier of the affected area (module,
component, subsystem).

### 1.5. Breaking changes

A breaking change is marked with `!` after the type/scope and a
`BREAKING CHANGE: <description>` footer line — both at once.

## 2. Commit content

### 2.1. One logical change per commit.

### 2.2. Commits are created only for the current task or plan.

### 2.3. What is not committed

Temp logs, diagnostic scripts, one-off workarounds and session
artifacts; the final result is committed, not the debugging history.
Exception — permanent project tools. Research runs make no commits.

### 2.4. Known broken state is not committed

All applicable local checks (tests, build, linters) run before the
commit; checks not affected by the change are not required.

## 3. History

### 3.1. History is not rewritten

Without the owner's explicit permission: no amend, rebase, reset,
force-push, and no deletion of baseline commits.

## 4. Examples

### 4.1. Commit messages

Correct

✅ `feat(audio-capture): add noise gate`
✅ `fix(parser)!: handle empty input`

Incorrect

❌ `Added audio-capture module` — no type, not imperative
❌ `chore: добавить шумоподавление` — message is not in English
