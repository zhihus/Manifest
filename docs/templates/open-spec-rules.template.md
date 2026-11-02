# OpenSpec Task Naming Rules

Universal rules for OpenSpec `tasks.md` — apply in any project.

## 1. Prefix

Every task: prefix `FR` (Functional Requirement).

## 2. Numbering

Sequential, per OpenSpec: `FR N.M` — `N` = group, `M` = task within group.

## 3. Title

A short description of a few words stating what the task does.

## 4. Kebab-case

Task names contain no spaces: spaces are replaced by hyphens. Example: `FR 1.1 Define ratio` → `fr-1.1-define-ratio`.

## 5. Wave

A dependency between deliverables: a deliverable is not developed until the one it depends on is complete. A wave = one group (`## N.`); groups are ordered by dependency (group `N` depends only on `1…N−1`). Execution: finish all tasks of a wave, mark `- [x]`, stop and report before the next wave.

## 6. No file references in the name

File references live only in the task body, never in the name.