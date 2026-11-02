# CODE_RULES.md

## Purpose

Produce simple, correct, explicit and maintainable code.

## Rules

* **Simplicity** — use the simplest correct solution; no unnecessary functionality or speculative abstractions.
* **Explicitness** — make dependencies, state, flow, side effects, ownership and error handling explicit; no hidden global state.
* **Responsibility + Locality** — give each component one clear responsibility; keep related logic and state local when this improves understanding.
* **Readability** — use clear, domain-meaningful names and project/language conventions; avoid unnecessary indirection, abbreviations and vague names.
* **Low Coupling** — minimise dependencies; prefer explicit dependencies over DI machinery when sufficient.
* **Established Patterns** — follow existing project patterns and authoritative sources before introducing APIs, abstractions, dependencies or conventions.
* **Change Discipline** — make the smallest change that solves the problem; preserve existing behaviour unless change is required; no unrelated rewrites; fix root causes.
* **Error Handling** — never silently swallow errors; handle, propagate or explicitly suppress them with useful context; validate inputs and enforce invariants. See `LOG_RULES.md` for logging.
* **Verification** — verify behaviour through direct, deterministic mechanisms; tests must validate outcomes, not merely execute. See `TEST_RULES.md` for test requirements. Passing tests are evidence, not proof.
* **Maintainability** — optimise for long-term evolution without sacrificing correctness; keep code understandable to humans and future agents.

## Exceptions

These are guidelines, not mechanical constraints. Deviate when required by correctness, security, performance, simplicity or established architectural constraints. Make non-obvious exceptions clear in code or documentation.