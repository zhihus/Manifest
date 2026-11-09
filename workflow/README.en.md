# OpenSpec Protocol

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-09**  

# Description
Process for working with LLM agents on the OpenSpec pipeline; task
rules live in `openspec-rules.md`.

## 1. Roles

The pipeline exists inside the **Orchestrator** context (the main session /
conductor). It never performs a specialist's job: it restores pipeline state,
dispatches the right subagent at each step, checks the agent's report, and
gates the transition to the next step. This preserves the core invariant:
**no role ever checks its own work.**

| Step | Artifact | Agent | Input → Output |
|---|---|---|---|
| — | pipeline state | Orchestrator | runs steps, gates transitions |
| 1 | proposal.md | Analyst | user's words → "why / what" |
| 2 | spec.md | Analyst | proposal → scenarios, edge cases, PBT |
| 3 | design.md | Architect | proposal + spec → solution (optional) |
| 4 | tasks.md | Planner | spec + design → atomic task checklist |
| 5.1 | tests | Tester | spec properties → tests before code |
| 5.2 | code or document | Implementer / Documenter | tasks + spec → implementation |
| 6 | verify.md | Reviewer | artifacts + spec → ✅/❌ report |
| 7 | archive | Orchestrator | verify all ✅ → specs updated |

Each role runs in its own agent session (subagent run). The Orchestrator may
combine roles across different changes but never within one deliverable.

## 2. The Seven Steps and Gates

### 2.1. Proposal (Analyst)

Answers *why* and *what* changes, without behavior detail or technical
solutions. Sections: `Why`, `What Changes`, `Capabilities`.

**Gate:** `Why` present, `What Changes` non-empty, capability list
explicit. Fail → back to Analyst.

### 2.2. Spec (Analyst)

The behavioral contract: every proposal requirement expanded into user
stories, `GIVEN / WHEN / THEN` scenarios, edge cases, and — where
executable behavior is expected — **properties for property-based tests
(P1, P2, …)**. The spec, not the code, is the source of truth for the
Tester. If a behavior is not in the spec, it does not exist.

**Gate:** every requirement has ≥1 scenario; edge cases listed; PBT
properties derived (for code changes). Fail → back to Analyst.

### 2.3. Design (Architect)

Technical plan: data structures, algorithms, trade-offs. May not
contradict the spec; on conflict the spec is edited deliberately (by
the Analyst), never silently worked around. Optional for small
changes, mandatory when there is a choice between solutions.

**Gate:** design references the spec and introduces no requirements
absent from it. Fail → back to Analyst (revisit spec).

### 2.4. Tasks (Planner)

Atomic, individually verifiable tasks, each traceable to a scenario or
property. Follows `openspec-rules.md`: FR numbering, wave groups, size
calibration (one task = one executor run, < 10 minutes, mechanical
stop criterion), `Maps to scenarios:` line.

**Gate:** every task is a checkbox and traceable to a scenario/property;
wave structure valid. Fail → back to Planner.

### 2.5. Apply (Tester → Implementer / Documenter)

Two distinct roles, in that order.

#### 2.5.1. The Tester writes tests before implementation

From `spec.md` only (properties P1–P3 …), never from code. This makes
tests check requirements, not chase the implementation.

#### 2.5.2. The Implementer writes the implementation against the tests

Input: `tasks.md` + `spec.md`. The Implementer never edits tests: a
failing test is a bug in the implementation. Properties change only
via a deliberate spec edit by the Analyst.

#### 2.5.3. The doc-only path

For documentation deliverables, step 5.1 is skipped (no executable
contract; the property "the document matches the spec" is checked by
reading). The Implementer role is performed by a **Documenter** — a
separate agent whose only job is to produce the document per
`spec.md` + `design.md`, marked `doc-only` in `tasks.md`. If a change
contains both code and docs, the Documenter runs as a separate
session, in parallel if desired. Review still happens (step 6) — a
semantic check: completeness, consistency, no requirements absent
from the spec.

**Gate:** for code — tests unmodified since the Tester wrote them; the
Implementer touched no test files. For doc-only — task marked
`doc-only`, artifact created, Documenter edited no spec files.
Fail → back to step 5.

### 2.6. Verify (Reviewer)

A conformance check against the spec, not a style review. For each
scenario and property: covered by a test and passing on the
implementation (code), or the document matches scenarios and adds
nothing new (doc-only). Tests are not tautological; all `tasks.md`
items closed. The Reviewer edits nothing — it produces `verify.md`
(✅/❌) and routes failures: test gap → Tester, failing test →
Implementer, spec contradiction → Analyst, incomplete doc →
Documenter.

**Gate:** `verify.md` contains only ✅ → proceed to step 7. Any ❌ →
route back and re-run the affected step.

### 2.7. Archive (Orchestrator / automation)

Triggered only after verify is all ✅. The delta-spec from
`changes/<name>/specs/` merges into the permanent `openspec/specs/`,
the change folder moves to `changes/archive/<date>-<name>/`.
Mechanical, usually a CLI operation (`openspec archive <name>`). From
this point the requirement is standing law for all future changes.

## 3. Relation to openspec-rules.md

* Steps 1–4 = "strong model / human" work per the rules file.
* Step 4 output = waves, FR numbering, size calibration.
* Step 5 = executor runs: one subagent run = one task (FR); executor
  commits after each completed stage.
* Heavy verification is its own task (step 6 in its own run).
* Archive (step 7) matches `openspec/changes/archive/`.

## 4. Language

All artifacts (`proposal.md`, `spec.md`, `design.md`, `tasks.md`,
`verify.md`) and process context files are written in English, unless a
project's rules state otherwise. Scenario bodies inside specs may be in the
project's domain language when required by the runtime that consumes them
(e.g. Russian Gherkin for 1C/Vanessa), while the spec document itself stays
English.

## 5. Minimal Runbook (user's view)

1. State the change in plain words; confirm edge cases when asked.
2. The Orchestrator drives steps 1–7, dispatching one role per step
   and reporting gate results.
3. You intervene only when a gate fails to a point the Orchestrator
   routes back to you (scope questions, spec conflicts) or at the
   final verify ✅.
