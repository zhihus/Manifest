# TEST_RULES.md

## Purpose

Define reliable, isolated and repeatable tests that verify behaviour.

## Rules

* **TDD** — write a test before implementation. No test → no code. Tests are prepared by the **Tester** role before implementation starts (TEST FIRST); the implementer never edits tests prepared by the Tester — a failing test is a bug in the implementation.
* **Isolation** — one test verifies one behaviour; tests must be isolated and repeatable.
* **Priority** — cover critical paths first: happy path, edge cases and error conditions.
* **Coverage** — cover all public APIs and critical business logic; target ≥80% for core modules unless project-specific requirements differ.
* **Regression** — reproduce a discovered bug with a regression test before fixing it.
* **Verification** — tests must validate outcomes, not merely execute.
* **Pre-commit** — all required local tests must pass before commit. Do not commit failing or skipped tests without explicit user approval.

## Structure

* **Unit** — individual functions/modules in isolation.
* **Integration** — interactions between components.
* **End-to-end** — full-system behaviour when required.
* Place tests alongside source code or in `tests/`, following project conventions.

## Naming

Use project/language conventions. Test names must describe behaviour, not implementation.

## Exceptions

Deviate only when required by correctness, project architecture or explicit user-approved constraints.