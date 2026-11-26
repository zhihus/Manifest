# Verification

## Windows CI

- Workflow: https://github.com/zhihus/Manifest/actions/runs/45888926478
- Runner: `windows-latest`
- Result: PASS
- Bootstrap regression suite: `50/50` passed.
- PowerShell syntax validation: passed for the installer and Windows bootstrap.
- Installer integration test: passed; package copied and verified, second installation refused without changing the existing copy.
- Bootstrap gate: `-Plan` succeeded; default invocation displayed the component plan and stopped for explicit approval without downloading the runtime.
- Linux-only execution of `bootstrap.sh` was skipped on the Windows runner; the Windows rejection guard was tested.

## Upstream package integrity

Compared Manifest `skills/tz-rezultat-hz/` with upstream `zhihus/tz-rezultat-hz` at commit `bc5e4a89fb9ebea7512df221852d651d090e2e6e`.

- Upstream skill files: 44.
- Manifest skill files compared: 44.
- Path, Git blob SHA, and file mode differences: 0.
- Upstream `LICENSE` and `THIRD-PARTY.md` retained.
- Bootstrap tests remain outside the distributable package at `tests/tz-rezultat-hz/`.

## Platform scope

Manifest-managed installation is implemented and tested on Windows x64 only. The upstream skill's Linux files are preserved, but Manifest Linux installation is not claimed.
