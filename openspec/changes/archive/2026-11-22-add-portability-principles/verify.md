# Verification: add-portability-principles

## Result

**PASS** — implementation reviewed against the change proposal, design, tasks, and spec scenarios.

## Review

- Public-file scope is derived from the current navigation files, tracked template/spec collections, and manifest-init source list.
- Forbidden-content checks, bidirectional RU/EN pairing, and dependency-register checks are wired into repository verification.
- The dependency scanner documents its conservative grammar and routes unsupported shell constructs and unavailable platform commands to mandatory human review.
- Infrastructure scripts use portable Bash/BSD-compatible utility options in the reviewed implementation.
- SHA-256 selection supports sha256sum and shasum -a 256; Perl is checked before project writes.
- The dependency register has Russian and English editions and is linked from the navigation file.
- Template references use canonical installed filenames; RELEASES.md remains a required base document but is excluded from the five-file MVP install set until its template exists.

## Test evidence

The implementation report supplied for commit 4a1a7004bc1bb4d173d21a01913940f22a22a1af records:

- verify.sh: PASS, 8.5 s
- test-portability.sh: PASS, 19/19, 20.9 s
- test-manifest-init.sh: PASS, 11/11, 12.8 s
- OpenSpec change validation: PASS
- OpenSpec permanent-spec validation: PASS

These are recorded as supplied execution evidence; this review did not rerun the local test suite.

## Specification reconciliation

Before archival, the delta requirements were merged into the permanent portability-principles, manifest-init, preflight, and template-install specifications. The template-install wording now distinguishes the six-document mandatory base set from the five currently installable MVP files.

## Scope

No connected-project files or local harness configuration are changed.
