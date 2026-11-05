# Planner Eval — Report 1: Primary Planner

**Evaluated:** the add-context-files-guard tasks.md as originally generated
in the Manifest repo (2026-11-02, before the 2026-11-05 rewrite; result
deleted by that rewrite — preserved in Manifest git history, commit series
ending at `adb0baa`).
**Executor target:** local model (Qwen3.8-27B), one run = one task, ≤10 min.
**Criteria set:** identical to report-2 (fixed for all future reports).

## Scores

| # | Criterion | Score | Evidence |
|---|---|---:|---|
| 1 | Capability coverage | 10/10 | All 6 capabilities mapped to groups 1–7 + acceptance group 8 |
| 2 | Wave/dependency correctness | 8/10 | Groups ordered by phase correctly; waves labeled "Phase", not per openspec-rules.md wave definition |
| 3 | Task naming per rules | 4/10 | Format `1.1 fr-1.1-name:` — FR prefix hidden inside kebab-case; rule format is `FR N.M Title` |
| 4 | Body self-containedness | 3/10 | One-line bodies (~300–500 chars); external references to "the source plan" (tasks 1.1, 8.1); no inlined values |
| 5 | Task sizing for executor | 5/10 | Bodies far below any meaningful unit of work; no stop criteria; no size discipline applied |
| 6 | Verification placement | 5/10 | "verify ..." appended to every task, but no mechanical stop criterion; heavy verification not separated |
| 7 | Rule-conflict handling | 4/10 | No conflicts flagged; header comment referenced rules the tasks themselves violate (naming) |
| 8 | Language consistency | 10/10 | All artifacts in English as required |

**Total: 49/80 → 6.1/10**

## Improvement Proposals

1. Adopt `FR N.M Title` naming with title in the name (done later, commit
   `8c78709`).
2. Require self-contained bodies: exact paths, what to change, mechanical
   stop criterion (done later).
3. Ban external references in task bodies; inline all values (done later).
4. Size tasks against the executor invariant (≤10 min, one run), not against
   document sections (later covered by the calibration block).

## Note

This planner worked before the calibrated rules existed; its score measures
the rules of its time, not the planner. Comparison with report-2 shows the
rule changes, not an intelligence difference.
