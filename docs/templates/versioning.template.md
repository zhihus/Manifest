# VERSIONING.md

## Format

* `X.Y.Z` (SemVer).
* If enabled: `X.Y.Z-{alpha|beta|rc}.N`.

## Source

* `VERSION` is the single source of truth.
* One version per line, no comments.
* No independent versions elsewhere.
* Released versions cannot be decreased or reused.

## Bump

* Breaking → major.
* Feature → minor.
* Bugfix/compatible → patch.
* Mixed → highest.
* Increment selected component; reset lower components to `0`.
* Update `VERSION` and follow `COMMIT_RULES.md`.

## Pre-release

* Same stage → increment `N`.
* New stage → `N=1`.
* Allowed progression: `alpha` → `beta` → `rc`; stages may be skipped.
* Major/minor/patch bump → `alpha.1`.
* Pre-release may become final directly.
* Pre-release < final release.

## Consumers

* Consumers derive the version from `VERSION`.
* Platform/build metadata must not define an independent version.