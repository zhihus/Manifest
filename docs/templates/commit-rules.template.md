# commit-rules.md

**Format:** `<type>(<scope>): <subject>`
- `type` — one of: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- `scope` — logical area of the codebase (module, component, subsystem), optional, use short stable identifiers (e.g., `audio-capture`, `config-loader`)
- `subject` — brief imperative summary in English, lowercase, target ≤50 characters but not a hard limit

**Body (optional):**  
Separate from subject by a blank line. Explain **why** the change is needed, what behaviour changes, and any non‑obvious decisions. Do not repeat the diff.

**Footer (optional):**  
Use for metadata like `Refs: #123`, `Closes: #456`, or `BREAKING CHANGE: <description>`.

**Breaking changes:**  
Add `!` after the type/scope **and** include `BREAKING CHANGE:` in the footer for clarity.

**Rules:**
1. One logical change per commit.
2. Run all applicable local checks (tests, build, linters) before committing.
3. Do not amend, rebase, reset, or force‑push existing commits without explicit permission.
4. All commit messages must be in English.