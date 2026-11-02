# releases.md

## Branches

* `develop` — all development (incl. documentation projects).
* `master` — approved documents / release-ready.
* OpenSpec change: branch name = OpenSpec task name (see `open-spec-rules.template.md`).

## Release

1. Build: `{{BUILD_COMMAND}}`.
2. Verify: `{{VERIFICATION_STEPS}}`.
3. Merge `develop` → `master` (`git merge develop`).
4. Build + verify `master`.
5. Tag: `git tag vX.Y.Z`.
6. Artifact: `{{RELEASE_ARTIFACT_PATH}}`.

## Rules

* One release = one tag = one version.
* Tags: only on `master`, immutable.
* Failed verification → no merge, no tag.
* No rebase, force-push, or direct commits to `master`.
* `master` must remain installable.