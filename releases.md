# releases.md

## Branches

* `develop` — all development (including documentation projects).
* `master` — approved documents / release-ready.
* OpenSpec change: branch name replicates the OpenSpec task name (see `open-spec-rules.template.md`).

## Release

1. Review: documents reviewed for accuracy, completeness, consistency.
2. Approve: explicit user approval of the document set.
3. Merge `develop` → `master` with `git merge develop`.
4. Verify `master` documents are consistent.
5. Tag: `git tag vX.Y.Z`.
6. Release artifact: approved documents on `master`.

## Rules

* One release = one tag = one version.
* Tags only on `master`.
* Tags are immutable.
* Failed review or approval → no merge, no tag.
* No rebase, force-push, or direct commits to `master`.
* `master` must remain a consistent, approved document set.