# External Dependency Register

# Metadata
> **Status: approved**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-27**  

# Description
The single source listing the external binary tools that Manifest
repository infrastructure scripts (`scripts/*.sh` and hooks under `scripts/hooks/`) may invoke.
Adding a new external dependency requires an entry in this register.
Entry format: tool, purpose, scope of use, detection method. The
Russian edition (`external-dependencies.ru.md`) is authoritative;
this file is its translation.

| Tool | Purpose | Scope | Detection |
| --- | --- | --- | --- |
| `bash` | interpreter for all infrastructure scripts | `scripts/*.sh` and `scripts/hooks/*` | `#!/usr/bin/env bash` |
| `git` | repository operations, changed-file detection | all infrastructure scripts and the `scripts/hooks/pre-commit` hook | preflight `command -v git` |
| SHA-256 (`sha256sum` or `shasum -a 256`) | config overwrite protection; byte checks | manifest-init.sh (checksum guard), test-manifest-init.sh (checksum regression fixture) | runtime detection: `sha256sum`, else `shasum -a 256`; the detected tool is used consistently |
| `perl` | manifest-init template rendering (placeholder and conditional substitution) | `skills/manifest-init/scripts/install.sh` | preflight: `command -v perl` and `perl -e 'exit 0'` |
| `mktemp` | unique temp files and directories (collision safety) | manifest-init.sh, verify.sh, test-manifest-init.sh, test-portability.sh | coreutils / Git for Windows / macOS |
| `awk` | checksum output parsing, fixture generation in verify.sh | manifest-init.sh, verify.sh | base system install; only portable constructs used |
| `cmp` | byte comparison of installed files against renders | manifest-init.sh, test-manifest-init.sh | coreutils / Git for Windows / macOS |
| `date` | config creation date `created=` | manifest-init.sh (`date +%F`, locale-independent) | base system install |
| `grep`, `sed` | leftover-placeholder checks, output filtering | all infrastructure scripts and tests | portable constructs only (no GNU-only flags) |
| `find` | project type analysis (code files, docs/) | manifest-init.sh (`analyze_project`), verify.sh, test-portability.sh | POSIX flags without GNU-only extensions |
| `basename`, `dirname` | project and script directory name extraction | manifest-init.sh, test-manifest-init.sh | portable system utilities |
| `head`, `wc` | line/word counting and output limiting in checks and tests | structure-parser.sh, test-manifest-init.sh | portable system utilities |
| `cut` | line-number field extraction from `grep -n` output | test-todoing-runbook.sh | portable system utility |
| `sort`, `tr` | violation sorting and token/output processing | structure-parser.sh, verify.sh, test-portability.sh | portable system utilities |
| `cat` | reading fixture files in tests | test-manifest-init.sh | portable system utility |
| `chmod` | setting the executable bit on the Perl test stub | test-manifest-init.sh | portable system utility |
| `env` | resolving Bash from PATH in shebangs | all executable shell scripts | system utility |
| `ln` | creating a symbolic link to test symlink-file exclusion | test-structure-parser.sh | POSIX utility; available in Unix-like environments and Git for Windows |
| `ln` | atomic no-clobber creation of new files | `skills/manifest-init/scripts/install.sh` | portable system utility; an existing destination causes failure and is preserved |\n| `install`, `cp`, `rm`, `mv`, `mkdir`, `ls` | file install, rollback and inspection | manifest-init.sh, test scripts | coreutils / Git for Windows |

## 1. Removed dependencies

- `python` — removed from verify.sh (fixture generator rewritten in
  Bash/awk); it is not a dependency and must not be registered.

## 2. Boundaries

The register describes the dependencies of the Manifest repository
infrastructure. It does not extend to connected projects and is not
part of the manifest-init distribution.
