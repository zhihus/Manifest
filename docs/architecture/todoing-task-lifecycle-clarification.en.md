# Todoing Task Lifecycle Clarification for Manifest

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-24**  

# Description
Clarifies previously incomplete rules for Todoing task states and permissions.

## 1. Reason for clarification

The Todoing integration contract and related architecture documents did not
fully describe the task lifecycle. Some agreements were not recorded explicitly,
and some provisions were interpreted incorrectly.

In particular, the displayed names of all states, transition permissions, and
the procedural prohibition against an agent authorizing its own task were not
defined unambiguously.

This document records the user's clarifications from 2026-11-24. When the
Manifest contract and implementation are updated, these rules take precedence
over earlier ambiguous task-lifecycle wording.

## 2. Task states

The user-facing task lifecycle consists of the following states:

| Internal ID | Display name | Meaning |
|---|---|---|
| `backlog` | Draft | The task is discussed with the user and prepared. Execution is not authorized. |
| `ready` | Ready | The user has authorized the task for execution. |
| `in_progress` | In Progress | The Orchestrator has assigned the task and work has started. |
| `review` | In Review | The Executor has finished and submitted the result for independent review. |
| `verified` | Verified | Another agent has reviewed the result and confirmed compliance. |
| `completed` | Completed | The Orchestrator has performed final checks and confirmed success. |
| — | Cancelled | The user decided that the task must not be performed; the Orchestrator recorded the cancellation. |

“Draft” is the user-facing name for Todoing state `backlog`, not a
separate state.

“Cancelled” is a user-facing terminal state. In Todoing, cancellation is
recorded as `outcome=cancelled`; the previous workflow status is not
overwritten. The history therefore preserves both the task's last working
state and the separate cancellation outcome.

## 3. Transition sequence

The normal execution path is:

1. `backlog` → `ready`: the user authorizes execution.
2. `ready` → `in_progress`: the Orchestrator assigns an Executor and starts work.
3. `in_progress` → `review`: the Executor finishes and submits the result for review.
4. `review` → `verified`: an independent Reviewer approves the result.
5. `verified` → `completed`: the Orchestrator performs final checks and completes the task.

If the Reviewer finds issues, the task returns from `review` to
`in_progress`. The Orchestrator arranges corrections; the Executor does
not review its own work.

The user may initiate cancellation before completion. The Orchestrator records
`outcome=cancelled` and performs the required cancellation actions for the
related OpenSpec change.

## 4. Permissions to change task states

### 4.1. Authorization to execute

Only the user may move a task from Draft (`backlog`) to Ready (`ready`).

No agent, including the Analyst and the Orchestrator, may perform this
transition independently or treat a task as authorized without the user's
explicit decision.

This transition is the user's authorization to start work. At that moment,
the Orchestrator records the current user-approved task version as the
baseline through Todoing `task.version.approve`.

### 4.2. Starting and handing off work

The Orchestrator moves a task from `ready` to `in_progress` when it
assigns an Executor and actually starts the work. An agent must not change
the state itself to declare that work has started.

The transition from `in_progress` to `review` occurs when the Executor
submits the result. The Orchestrator verifies that the result was submitted
for review and records the transition.

The transition from `review` to `verified` occurs only after an
independent Reviewer has reported its result. The Executor cannot approve
its own work.

Only the Orchestrator may move a task from `verified` to `completed`,
and only after final checks confirm successful execution.

### 4.3. Procedural enforcement of permissions

Role-based authority in Manifest is enforced as a procedural rule followed by the Orchestrator and role agents; it is not implemented through technical isolation from the Todoing CLI/API.

Only the user may authorize the transition from `backlog` to `ready`. The Orchestrator must obtain the user's explicit confirmation and must not treat an agent recommendation or action as that confirmation.

Under the agreed procedure, the Orchestrator coordinates Todoing changes and checks whether each transition is permitted. Role agents should not independently change task states or perform Todoing operations outside their assigned responsibilities. This is an organizational requirement; it does not mean that the environment technically blocks an agent's direct access to the CLI/API.

Todoing does not authenticate users or agents. The `actor_id` field records the technical actor asserted by the caller, but does not by itself prove the identity of the decision-maker or the existence of user approval. Where reliable attribution of a user decision is required, Manifest must retain a separate reference to the user's confirmation rather than treating `actor_id` as proof.

## 5. Cancellation by user decision

An agent may only recommend cancellation and provide its reasoning. It
cannot cancel a task independently.

The cancellation decision always belongs to the user. The user informs the
Orchestrator of that decision; the Orchestrator records the cancellation in
Todoing and archives the related OpenSpec change through the standard process.

Todoing history must make the following facts unambiguous:

- The user is the initiator and source of the cancellation decision.
- The Orchestrator performed the cancellation in response to that decision.
- If an agent recommended cancellation, it was only the author of a
  recommendation, not the decision-maker.

The Orchestrator's technical `actor_id` alone does not prove who made the
decision. Manifest must separately preserve the confirmed cancellation
initiator and the reference to the user's confirmation.

## 6. Completion conditions

The “Verified” state does not by itself mean that the task is complete.

The Orchestrator moves the task to “Completed” only after final acceptance:
the result meets the requirements, mandatory checks have passed, and the
related OpenSpec and Git actions have been performed in the required order.

Only then does Todoing receive outcome `completed`. A commit or a positive
report from a single agent is not sufficient grounds for completion.

## 7. What this clarifies in earlier documents

1. The previously proposed six-state configuration did not fully represent
   the user's agreed lifecycle or define all Russian display names.
2. The user's authority to approve execution through
   `backlog` → `ready` was mentioned, but the technical exclusivity
   of that authority was not specified strictly enough.
3. The separate permissions for starting work, submitting it for review,
   approving the review, and completing the task were not explicit.
4. Cancellation was previously described only as outcome `cancelled`.
   This clarification also defines the user-facing terminal state
   “Cancelled” and requires recording that the user made the decision.
   The Todoing representation remains a separate outcome and does not
   overwrite the last workflow status.
5. Baseline approval is tied directly to the user's transition from
   “Draft” to “Ready”.

## 8. Applying this clarification

This is a separate architecture clarification. It does not rewrite the
historical record of earlier decisions.

When `todoing-contract.ru.md`, the status configuration, and the Manifest
runbook are next updated, they must be aligned with this document. Until then,
the absence of explicit user approval must not be interpreted as
permission for agents to change the `ready` state.

