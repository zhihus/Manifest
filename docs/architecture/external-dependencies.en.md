# External Dependency Register

# Metadata
> **Status: approved**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-22**  

# Description
The single source listing the external binary tools that Manifest
repository infrastructure scripts (`scripts/*.sh`) may invoke.
Adding a new external dependency requires an entry in this register.
Entry format: tool, purpose, scope of use, detection method. The
Russian edition (`external-dependencies.ru.md`) is authoritative;
this file is its translation.

| Tool | Purpose | Scope | Detection |
| --- | --- | --- | --- |
| `bash` | interpreter for all infrastructure scripts | all `scripts/*.sh` | `#!/usr/bin/env bash` |
| `git` | repository operations, changed-file detection | verify.sh, structure-parser.sh (indirect), manifest-init.sh (work-tree check) | preflight `command -v git` |
| SHA-256 (`sha256sum` or `shasum -a 256`) | config overwrite protection; byte checks | manifest-init.sh (checksum guard) | runtime detection: `sha256sum`, else `shasum -a 256`; the detected tool is used consistently |
| `perl` | manifest-init template rendering (placeholder and conditional substitution) | manifest-init.sh, `render_template` | not detected separately; shipped with Git for Windows, macOS, Linux |
| `mktemp` | unique temp files and directories (collision safety) | manifest-init.sh, verify.sh | coreutils / Git for Windows / macOS |
| `awk` | checksum output parsing, fixture generation in verify.sh | manifest-init.sh, verify.sh | base system install; only portable constructs used |
| `cmp` | byte comparison of installed files against renders | manifest-init.sh | coreutils / Git for Windows / macOS |
| `date` | config creation date `created=` | manifest-init.sh (`date +%F`, locale-independent) | base system install |
| `grep`, `sed` | leftover-placeholder checks, output filtering | manifest-init.sh, verify.sh | portable constructs only (no GNU-only flags) |
| `find` | project type analysis (code files, docs/) | manifest-init.sh (`analyze_project`) | portable flags |
| `install`, `cp`, `rm`, `mv`, `mkdir`, `ls` | file install, rollback and inspection | manifest-init.sh, test scripts | coreutils / Git for Windows |

## 1. Removed dependencies

- `python` — removed from verify.sh (fixture generator rewritten in
  Bash/awk); it is not a dependency and must not be registered.

## 2. Boundaries

The register describes the dependencies of the Manifest repository
infrastructure. It does not extend to connected projects and is not
part of the manifest-init distribution.
