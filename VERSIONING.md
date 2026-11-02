# VERSIONING.md

## Format

* `X.Y.Z` (SemVer).
* If enabled: `X.Y.Z-{alpha|beta|rc}.N`.

## Source

* `VERSION` is the single source of truth for its project.
* One version per line, no comments.
* No independent versions elsewhere within the same project.
* Released versions cannot be decreased or reused.

## Sub-projects

* A head project's sub-projects (under `skills/`) are separate projects.
* Each sub-project keeps its own `VERSION`, independent of the head project's version.

## Bump

* Breaking → major.
* Feature → minor.
* Bugfix/compatible → patch.
* Mixed → highest.
* Increment selected component; reset lower components to `0`.
* Update `VERSION` and follow `commit-rules.md`.

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