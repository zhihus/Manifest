# Tasks: sync-architecture-docs

## 1. Architecture documents sync

- [x] FR 1.1 Sync architecture-brief.ru.md with decisions of 20–21.11.2026

  Edit `architecture-brief.ru.md`: header v0.2.0 → v0.3.0 with sync note;
  §6 sequential execution replaces parallel temp-branch allowance; §7
  Analyst task preparation and Todoing integration block (CLI/JSON,
  user-configured statuses, history/versions, exclusive locks with
  read-blocking, no physical delete, separate archive, optional hooks,
  SQLite preliminary, backup by Manifest, Project ID); §9 seven roles
  incl. Tester and Analyst, escalation loop, GLM-5.3 Flash orchestrator;
  §11 context-file protection priorities and Controlled File Update;
  §13 add Architect/Planner row.
  Stop criterion: all listed sections updated; grep finds "Tester",
  "Analyst", "GLM-5.3 Flash", "Controlled File Update" in the file.
  Maps to scenarios: brief reflects accepted decisions.

- [x] FR 1.2 Sync architecture-decisions.ru.md statuses

  Edit `architecture-decisions.ru.md`: add В (Выполнено) and НР
  (Не реализовано) statuses; mark analytical work done; close Tester,
  parallelism, escalation-loop questions; Todoing lock/read-blocking,
  archive restore, hooks optionality, backup ownership, Project ID;
  §12 summary updated.
  Stop criterion: statuses consistent; §12 no longer lists Tester and
  parallelism as open.
  Maps to scenarios: decisions register reflects agreed state.

- [x] FR 1.3 Mark closed audit findings

  Edit `architecture-audit.ru.md`: add status preamble (closed: C-1,
  E-5, E-6; remaining items listed); audit body unchanged.
  Stop criterion: preamble present, body untouched.
  Maps to scenarios: audit reflects post-sync state.

- [x] FR 1.4 Sync Todoing decisions with PR #1 target docs

  Edit `docs/todoing-architecture-decisions.ru.md`: v0.1.0 → v0.2.0;
  reference PRODUCT.md and docs/architecture/decisions.md from PR #1
  (todoing-x, branch docs/product-and-architecture-baseline); §3.3
  extended with lock/read-blocking, configurable statuses, archive
  restore, optional hooks, Project ID, backup ownership; prototype
  status noted.
  Stop criterion: references present, §3.3 extended.
  Maps to scenarios: todoing decisions match target docs.

## 2. Workflow and templates sync

- [x] FR 2.1 Update workflow READMEs (en + ru)

  Edit `workflow/README.en.md` and `workflow/README.ru.md`: version
  1.0.0 → 1.1.0, Updated 2026-11-21; sequential-execution rule; step 0
  Analyst row; Orchestrator model note; escalation loop; pointer to
  Brief §9 role list.
  Stop criterion: both files updated with matching content.
  Maps to scenarios: workflow matches role model.

- [x] FR 2.2 Extend test rules template with TEST FIRST and Tester

  Edit `docs/templates/code-test-rules.template.md`: TDD rule extended
  with Tester role preparation and implementer-must-not-edit-tests rule.
  Stop criterion: TDD bullet mentions Tester and TEST FIRST.
  Maps to scenarios: test template matches TEST FIRST.
