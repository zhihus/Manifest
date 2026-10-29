# RELEASES.md

## Branches

* `dev` — development only.
* `master` — release-ready only.

## Release

1. Build: `{{BUILD_COMMAND}}`.
2. Verify: `{{VERIFICATION_STEPS}}`.
3. Merge `dev` → `master` with `git merge dev`.
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