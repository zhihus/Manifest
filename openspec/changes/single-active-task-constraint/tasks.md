## 1. Primary normative source

- [x] fr-1.1-add-rule-to-agent-workflow
  Add a "Single active task" section to
  `skills/manifest-init/references/todoing-agent-workflow.md` stating: the
  Main Orchestrator MUST NOT start executing another task while a current task
  is active (`in_progress`, `review`, or `verified`); a task in `backlog` or
  `ready` is not active and a task with outcome `completed` or `cancelled` is
  not active; the only exception is explicit user instruction; the rule applies
  regardless of initiator and method; on a block the agent reports the active
  task and waits. Place it before "Execution and lock custody".
  Stop: the section is present, defines "active", states the exception and the
  method/actor independence, and matches `specs/single-active-task/spec.md`.
  Maps to scenarios: second task blocked; explicit user exception; method-independent

## 2. Onboarding guide

- [x] fr-2.1-propagate-to-onboarding
  Add the single-active-task rule to `workflow/connected-agent-onboarding.ru.md`
  section 5 (Полномочия и lifecycle), then synchronize the faithful English
  translation in `workflow/connected-agent-onboarding.en.md`. Keep the Russian
  edition authoritative and do not change unrelated sections.
  Stop: both editions state the same rule (active states, exception,
  method/actor independence, report-and-wait on block) and the RU/EN meaning
  matches.
  Maps to scenarios: second task blocked; new task allowed after completion; method-independent

## 3. Workflow runbook

- [x] fr-3.1-propagate-to-runbook
  Add the single-active-task rule to `workflow/README.ru.md` section 6.2
  (Контракт API и задача) near the task-dispatch guidance, then synchronize the
  faithful English translation in `workflow/README.en.md`. Keep the Russian
  edition authoritative and do not change unrelated sections.
  Stop: both editions state the same rule and agree with the agent workflow
  reference and the onboarding guide.
  Maps to scenarios: second task blocked; creating or preparing a task is not execution

## Verification status

Verified: the single-active-task rule is present and consistent across the
four normative documents — `skills/manifest-init/references/
todoing-agent-workflow.md` ("Single active task"), `workflow/
connected-agent-onboarding.ru.md` / `.en.md` (section 5), and `workflow/
README.ru.md` / `.en.md` (section 6.2). All four state the same rule: active
states are `in_progress`/`review`/`verified`; `backlog`/`ready` and
`completed`/`cancelled` are not active; "start executing" means acquiring the
lock and moving to `in_progress`; creating a task or moving it to `ready` is
not execution; the only exception is an explicit user instruction; the rule is
method- and actor-independent (`actor_id` is attribution, not an exemption);
on a block the agent reports the active task and waits. The Russian editions
are authoritative and the English editions are faithful translations. No
Todoing binary, API, or store behavior was changed; no status graph, lock
semantics, or review cycle was modified.