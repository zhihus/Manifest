# Design: single-active-task-constraint

## Decisions

1. The rule is a normative constraint on the Main Orchestrator's dispatch
   behavior, not a technical enforcement inside Todoing. Todoing locks are
   per-task; they do not prevent a second task from being started. The
   constraint is therefore procedural and documented in the agent workflow
   reference and the onboarding/runbook documents.
2. "Active task" means a task whose current status is `in_progress`, `review`,
   or `verified`. These are the non-terminal, already-started states. A task in
   `backlog` or `ready` is not active; a task with outcome `completed` or
   `cancelled` is not active.
3. The agent MUST NOT start executing a second task while an active task exists.
   "Start executing" means acquiring the lock and moving the task to
   `in_progress` (or any later execution state). Creating a task in `backlog` or
   moving it to `ready` is allowed and does not count as starting execution.
4. The only exception is an explicit user instruction. A request to discuss,
   analyze, draft, or prepare is not such an instruction.
5. The rule applies regardless of who initiated the task and by what method:
   user, agent, subagent, CLI, JSON API, or any other invocation path.
   `actor_id` is attribution, not authentication, so the rule is not scoped to
   a particular actor.
6. When the constraint blocks a new task, the agent MUST report the block and
   the active task it conflicts with, and wait for the user's decision. It MUST
   NOT silently drop or reorder the request.

## Scope boundary

Manifest is a documentation-led framework. The Main Orchestrator is the Main
Agent, not a new executable service. The rule is implemented as text in the
normative documents; no binary, API, or store change is made. The rule does not
change the Todoing status graph, lock semantics, or review cycle.