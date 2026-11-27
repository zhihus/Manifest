# Design: Todoing Agent Workflow

## Scope

This change completes Manifest-side agent instructions and acceptance coverage for
stage 1 (Todoing task management). It does not implement the later Todoing/OpenSpec
cross-component workflow, change OpenSpec feature defaults, approve context templates,
or alter Todoing itself.

## Runtime model

Manifest is a documentation-driven head/meta project; the Main Orchestrator executes
the workflow by invoking the public Todoing JSON API. No new background service or
local model/server configuration is introduced.

## Todoing-only lifecycle

When Todoing is enabled and OpenSpec is disabled:

1. Discover active tasks before creating a new one.
2. Reuse an existing task with the same intended outcome.
3. Create one Backlog task for an independently meaningful outcome; do not create
   separate Todoing tasks for implementation substeps.
4. Treat an explicit user instruction to execute the work as approval for
   `backlog → ready`; record the approved version baseline.
5. Check dependencies, acquire the task lock, and transition to `in_progress`.
6. Record commits, hand off to an independent Reviewer, and persist the Review.
7. After acceptance checks, record the final commit, complete the task, and release
   the lock.
8. Cancellation remains user-controlled. No OpenSpec references or archive commands
   are used in this mode.

Locked tasks are omitted from `task.list`; uncertainty about a potentially locked
task must not be interpreted as proof that no matching task exists. The project keeps
one active global task and one Main Orchestrator.

## API compatibility

Manifest acceptance CI builds Todoing from
`653788a954d2a120db1beba854308982814d8222`. This commit contains the generic
external-reference, Review, and final-commit operations required by the full
Manifest workflow. The current public Todoing `main` branch does not contain those
operations. A compatible build must use the pinned commit or a verified descendant.

The CLI invocation is `todoing --json api`, with one JSON request on stdin and one
JSON response on stdout.

## Trust boundary

Todoing's `actor_id` is attribution, not authentication. Main Orchestrator-only API
usage and lock-token custody are workflow rules, not an API-level authorization
mechanism. Role agents must not receive the token or be instructed to call Todoing.
If the execution environment gives role agents unrestricted direct CLI access, this
does not technically enforce the role boundary; that limitation must be reported
rather than described as a security guarantee.

## Verification

- Static runbook checks verify both language editions and the Todoing-only branch.
- The real API acceptance suite creates a separate project without an `openspec/`
  directory and exercises the standalone lifecycle.
- CI uses the pinned Todoing source commit.
- Local verification against the user's installed binary remains necessary to confirm
  that the binary was built from a compatible source revision.
