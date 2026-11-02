# RELEASES.md

## Branches

* `develop` — all development (including documentation projects).
* `master` — approved documents / release-ready.
* OpenSpec change: branch name replicates the OpenSpec task name (see `open-spec-rules.template.md`).

## Release

1. Build: `{{BUILD_COMMAND}}`.
2. Verify: `{{VERIFICATION_STEPS}}`.
3. Merge `develop` → `master` with `git merge develop`.
4. Build and verify `master`.
5. Tag: `git tag vX.Y.Z`.
6. Release artifact: `{{RELEASE_ARTIFACT_PATH}}`.

## Rules

* One release = one tag = one version.
* Tags only on `master`.
* Tags are immutable.
* Failed verification → no merge, no tag.
* No rebase, force-push, or direct commits to `master`.
* `master` must remain installable.