# Planner Eval — Report 2: Fresh Agent Planner

**Evaluated:** same-model planning agent (2026-11-05), clean context, inputs
= proposal.md + design.md + specs + calibrated rules (config.yaml context,
rules.tasks, openspec-rules.md); no access to any existing plan.
**Executor target:** local model (Qwen3.8-27B), one run = one task, ≤10 min.
**Criteria set:** identical to report-1.

## Result summary

18 tasks / 6 waves; capabilities covered in dependency order: policy →
authorization → git-enforcement → installation → zcode-approval-bridge →
pr-workflow + e2e suite.

## Scores

| # | Criterion | Score | Evidence |
|---|---|---:|---|
| 1 | Capability coverage | 10/10 | All 6 capabilities mapped; checksum self-protection folded into the fail-closed task (coverage intact) |
| 2 | Wave/dependency correctness | 9/10 | Correct order; one rule-dependency across waves (branch rule needed in wave 1, formalized in wave 6) resolved by inlining |
| 3 | Task naming per rules | 10/10 | `FR N.M Title` throughout, kebab-case branch mapping, no file refs in names |
| 4 | Body self-containedness | 8/10 | Values, paths, states, commands inlined; short `spec: "<scenario>"` pointers kept — allowed by its own interpretation, not by a rule (gap) |
| 5 | Task sizing for executor | 7/10 | Calibration followed; two bodies ~5.5k chars at the 6000 ceiling — a 10-min-limit risk for code+script pairs; no code-specific char ceiling existed (gap) |
| 6 | Verification placement | 8/10 | PoC gate and e2e suite as own tasks; per-module tests kept inside implementation tasks by design judgment, not by rule (gap) |
| 7 | Rule-conflict handling | 9/10 | Four doubts surfaced explicitly and resolved; one silent merge (checksum into fail-closed) without flagging |
| 8 | Language consistency | 8/10 | Artifacts in English; implementation language (PowerShell/shell/Node) inferred from design.md wording, not taken from a Decisions reference (gap) |

**Total: 69/80 → 8.6/10**

## Improvement Proposals (gaps → rules)

1. Code-task character ceiling (hard, ~4000); implementation + its scripted
   verification scenario = one pair; above the ceiling the scenario becomes
   its own task.
2. Allow exactly one `Maps to scenarios: <names>` line per task body;
   declare it not-an-external-reference.
3. Implementation language/stack must come from design.md Decisions, never
   inferred.
4. Cross-wave rule dependency: inline the rule itself + note
   "rule formalized in FR x.y".
5. Planner self-check checklist (capabilities covered; every task ≤10 min
   by calibration; no oversized code tasks; stack sourced from design)
   added to openspec-rules.md.

All five were accepted as rule changes on 2026-11-05 (see repo commit
history; rules live in `openspec/config.yaml` and `openspec-rules.md` of
the three projects: Manifest, context-files-guard, skills/compress-context).

## Verification run (planner run 2, same criteria)

After the rule changes, the same experiment was repeated: 22 tasks / 7
waves; Plan Self-Check — all items pass; code ceiling respected; heavy
verification split (FR 3.5, 5.4, 7.1); `Maps to scenarios:` on every task;
cross-wave rule noted per the new rule. Two spec defects surfaced by run 2
were fixed in context-files-guard commit `ff6e3b5`: policy-file path
aligned with proposal; implementation stack added to design.md Decisions.

## Note

Report-1 measured a planner working under the old rules; report-2 measures
the same process under calibrated rules. Future reports reuse this criteria
set unchanged.
