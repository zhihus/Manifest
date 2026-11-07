# OpenSpec Workflow: User–Agent Interaction Protocol

> **Status: draft — under development.** This protocol is preliminary and
> may change; it is not yet a standing rule of the project.

Universal process for producing specifications and deliverables with LLM
agents, built on the OpenSpec change pipeline (`proposal → specs → design →
tasks → apply → verify → archive`). Applies to any project; project-specific
details (stack, test runners, naming) are delegated to that project's own
context files.

Companion rules: `openspec-rules.md` (task naming, waves, size calibration)
and `openspec/config.yaml` (per-artifact rules, context).

## 1. Roles

The pipeline exists inside the **Orchestrator** context (the main session /
conductor). It never performs a specialist's job: it restores pipeline state,
dispatches the right subagent at each step, checks the agent's report, and
gates the transition to the next step. This preserves the core invariant:
**no role ever checks its own work.**

| Step | Document / artifact | Agent | Input → Output |
|---|---|---|---|
| — | Pipeline state, gates, routing | **Orchestrator** | runs steps, checks reports, transitions/returns |
| 1 | `proposal.md` | **Analyst** | user's words → "why / what" |
| 2 | `specs/<capability>/spec.md` | **Analyst** | proposal → user stories, GIVEN/WHEN/THEN scenarios, edge cases, properties for property-based tests |
| 3 | `design.md` | **Architect** | proposal + spec → technical solution (optional for small changes) |
| 4 | `tasks.md` | **Planner** | spec + design → atomic task checklist |
| 5.1 | tests | **Tester** — separate role, before implementation, written from `spec.md` only | spec properties → executable tests |
| 5.2 | code **or** document | **Implementer** / **Documenter** (`doc-only`) | `tasks.md` + `spec.md` → implementation against tests, or document matching the spec |
| 6 | `verify.md` | **Reviewer** | artifacts + tests (if any) + spec + tasks → ✅/❌ report with routing |
| 7 | archive | **Orchestrator / automation** | verify all ✅ → specs updated |

Each role runs in its own agent session (subagent run). The Orchestrator may
combine roles across different changes but never within one deliverable.

## 2. The Seven Steps and Gates

### Step 1 — Proposal (Analyst)
Answers *why* and *what* changes, without behavior detail or technical
solutions. Sections: `Why`, `What Changes`, `Capabilities` (ADDED/MODIFIED/REMOVED).

**Gate:** `Why` present, `What Changes` non-empty, capability list explicit.
Fail → back to Analyst.

### Step 2 — Spec (Analyst)
The behavioral contract: every proposal requirement expanded into user
stories, use cases, verifiable `GIVEN / WHEN / THEN` scenarios, edge cases,
and — where executable behavior is expected — derived **properties for
property-based tests (P1, P2, …)**. The spec, not the code, is the source of
truth for the Tester. If a behavior is not in the spec, it does not exist.

**Gate:** every requirement has ≥1 scenario; edge cases listed; PBT
properties derived (for code changes). Fail → back to Analyst.

### Step 3 — Design (Architect)
Technical plan: data structures, algorithms, trade-offs. May not contradict
the spec; on conflict the spec is edited deliberately (by the Analyst), never
silently worked around. Optional for small changes, mandatory when there is a
choice between solutions.

**Gate:** design references the spec and introduces no requirements absent
from it. Fail → back to Analyst (revisit spec), not a silent design fix.

### Step 4 — Tasks (Planner)
Atomic, individually verifiable tasks, each traceable to a scenario or
property. Follows `openspec-rules.md`: FR numbering, wave groups, size
calibration (one task = one executor run, < 10 minutes, mechanical stop
criterion), `Maps to scenarios:` line.

**Gate:** every task is a checkbox and traceable to a scenario/property;
wave structure valid. Fail → back to Planner.

### Step 5 — Apply (Tester → Implementer / Documenter)
Two distinct roles, in that order:

**5.1 Tester writes tests BEFORE implementation** — from `spec.md` only
(properties P1–P3 …), never from code. This makes tests check requirements,
not chase the implementation.

**5.2 Implementer writes the implementation against those tests.** Input:
`tasks.md` + `spec.md`. The Implementer never edits tests: a failing test is
a bug in the implementation. Properties change only via a deliberate spec
edit by the Analyst.

**doc-only path (documentation deliverables):** Step 5.1 is skipped (no
executable contract; the property "the document matches the spec" is checked
by reading). The Implementer role is performed by a **Documenter** — a
separate agent whose only job is to produce the document per `spec.md` +
`design.md`, marked `doc-only` in `tasks.md`. If a change contains both code
and docs, the Documenter runs as a separate session, in parallel if desired.
Review still happens (Step 6) — semantic check: completeness, consistency,
no requirements absent from the spec.

**Gate:** for code — tests unmodified since the Tester wrote them; the
Implementer touched no test files. For doc-only — task marked `doc-only`,
artifact created, Documenter edited no spec files. Fail → back to Step 5.

### Step 6 — Verify (Reviewer)
A conformance check against the spec, not a style review. For each scenario
and property: covered by a test and passing on the implementation (code), or
the document matches scenarios and adds nothing new (doc-only). Also: tests
are not tautological; all `tasks.md` items closed. The Reviewer edits
nothing — it produces `verify.md` (✅/❌) and routes failures: test gap →
Tester, failing test → Implementer, spec contradiction → Analyst, incomplete
doc → Documenter.

**Gate:** `verify.md` contains only ✅ → proceed to Step 7. Any ❌ → route
back and re-run the affected step.

### Step 7 — Archive (Orchestrator / automation)
Triggered only after verify is all ✅. The delta-spec from
`changes/<name>/specs/` merges into the permanent `openspec/specs/`, the
change folder moves to `changes/archive/<date>-<name>/`. Mechanical, usually
a CLI operation (`openspec archive <name>` / `/opsx:archive`). From this
point the requirement is standing law for all future changes.

## 3. Relation to `openspec-rules.md`

* Steps 1–4 = "strong model / human" work per the rules file.
* Step 4 output = waves + FR numbering + size calibration defined there.
* Step 5 = executor runs: one subagent run = one task (FR); executor commits
  after each completed stage.
* Heavy verification is its own task (Step 6 belongs to its own run).
* Archive (Step 7) matches `openspec/changes/archive/` conventions.

## 4. Language

All artifacts (`proposal.md`, `spec.md`, `design.md`, `tasks.md`,
`verify.md`) and process context files are written in English, unless a
project's rules state otherwise. Scenario bodies inside specs may be in the
project's domain language when required by the runtime that consumes them
(e.g. Russian Gherkin for 1C/Vanessa), while the spec document itself stays
English.

## 5. Minimal Runbook (user's view)

1. State the change in plain words (e.g. "I want to record expenses and see
   the monthly total per category"); confirm edge cases when asked.
2. The Orchestrator drives steps 1–7, dispatching one role per step and
   reporting gate results.
3. You intervene only when a gate fails to a point the Orchestrator routes
   back to you (scope questions, spec conflicts) or at the final verify ✅.
