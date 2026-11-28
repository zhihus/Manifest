# Introduce a single-active-task constraint for the agent

## Why

The Manifest agent workflow currently has no normative rule that limits the
agent to one active task at a time. The Main Orchestrator can start executing a
second task while a first task is still in progress (not completed and not
canceled). This violates the lock-custody and review model, which assumes a
single task is being driven through `in_progress → review → verified →
completed` at a time, and it makes task history and lock fencing ambiguous when
two tasks interleave.

## What Changes

- Add a normative rule: the agent MUST NOT start executing another task while
  the current task is active (not completed and not canceled).
- Define "active" as a task whose status is `in_progress`, `review`, or
  `verified` — that is, a task that has been started but has not reached a
  terminal outcome of `completed` or `cancelled`.
- Allow an exception only on explicit user instruction.
- Make the rule apply regardless of who initiated the task (user, agent, or
  subagent) and by what method (CLI, JSON API, or any other invocation).
- Document the rule in the Todoing agent workflow reference, the connected-agent
  onboarding guide, and the workflow runbook (Russian authoritative edition
  first, then the English translation).

## Impact

- Affects `skills/manifest-init/references/todoing-agent-workflow.md`,
  `workflow/connected-agent-onboarding.ru.md` / `.en.md`, and
  `workflow/README.ru.md` / `.en.md`.
- No Todoing binary, API, or store behavior changes. The rule is a procedural
  constraint on the Main Orchestrator, not a technical enforcement in Todoing.
- Existing tasks and stores are not migrated or rewritten.