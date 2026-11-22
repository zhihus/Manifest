#!/usr/bin/env bash
# manifest-init.sh — initialize Manifest in a project (MVP stage 1).
# Usage:
#   manifest-init.sh --templates <dir> [--project <dir>]
#                    [--project-name <name>] [--purpose <text>]
#                    [--initial-version <v>]
#                    [--tracks none|code|documentation|mixed]
# Exit codes: 0 OK, 2 usage, 3 conflicts, 1 preflight/guard failure.
set -euo pipefail

PROJECT=.
TEMPLATES=
PROJECT_NAME=
PURPOSE=
INITIAL_VERSION=0.1.0
TRACKS=
ASK_NAME=0
ASK_TRACKS=0

usage() {
  echo "usage: manifest-init.sh --templates <dir> [--project <dir>] [--project-name <name>] [--purpose <text>] [--initial-version <v>] [--tracks none|code|documentation|mixed]"
  exit 2
}

while (($#)); do
  case "$1" in
    --project | --templates | --project-name | --purpose | --initial-version | --tracks)
      (($# >= 2)) || usage
      case "$1" in
        --project) PROJECT=$2 ;;
        --templates) TEMPLATES=$2 ;;
        --project-name) PROJECT_NAME=$2 ;;
        --purpose) PURPOSE=$2 ;;
        --initial-version) INITIAL_VERSION=$2 ;;
        --tracks) TRACKS=$2 ;;
      esac
      shift 2 ;;
    *) usage ;;
  esac
done
[[ -n $TEMPLATES ]] || usage
case $TRACKS in
  "" | none | code | documentation | mixed) ;;
  *) usage ;;
esac

MK=$PROJECT/.manifest

analyze_project() {
  local has_code=0 has_docs=0
  find "$PROJECT" -path "$PROJECT/.manifest" -prune -o \
    -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.cs' -o \
    -name '*.go' -o -name '*.java' -o -name '*.js' -o -name '*.py' -o \
    -name '*.rs' -o -name '*.sh' -o -name '*.ts' \) -print |
    awk 'NR == 1 { found = 1 } END { exit !found }' && has_code=1
  [[ -d $PROJECT/docs ]] && has_docs=1
  if ((has_code && has_docs)); then echo mixed
  elif ((has_code)); then echo code
  elif ((has_docs)); then echo documentation
  else echo none
  fi
}

ask() { # ask <prompt-var> <prompt> — read a line; EOF is fatal (nothing written yet).
  local var=$1
  printf '%s' "$2"
  if ! read -r "$var"; then
    echo "INTERVIEW_EOF: no answer could be read (EOF on stdin); nothing was written to the project" >&2
    exit 1
  fi
}

interview() {
  local proposed
  proposed=$(analyze_project)
  if [[ -z $PROJECT_NAME ]]; then
    ASK_NAME=1
    ask PROJECT_NAME "Project name [$(basename "$PROJECT")]: "
    [[ -n $PROJECT_NAME ]] || PROJECT_NAME=$(basename "$PROJECT")
  fi
  if [[ -z $TRACKS ]]; then
    ASK_TRACKS=1
    ask TRACKS "Tracks — proposed: $proposed [confirm/change] (none|code|documentation|mixed): "
    case $TRACKS in
      code | documentation | mixed | none) ;;
      *) TRACKS=$proposed ;;
    esac
  fi
  if [[ -z $PURPOSE && ( $ASK_NAME -eq 1 || $ASK_TRACKS -eq 1 ) ]]; then
    ask PURPOSE "Project purpose [optional, Enter to skip]: "
  fi
  [[ -n $PURPOSE ]] || PURPOSE="Purpose: not established."
}

INSTALLED=()
CONFLICTS=()
SKIPPED=()

report() {
  echo "== CONFIG"
  sed 's/^/  /' "$MK/manifest.yaml"
  echo "== INSTALLED (${#INSTALLED[@]})"
  if ((${#INSTALLED[@]})); then printf '  %s\n' "${INSTALLED[@]}"; fi
  echo "== CONFLICTS (${#CONFLICTS[@]})"
  if ((${#CONFLICTS[@]})); then printf '  %s\n' "${CONFLICTS[@]}"; fi
  echo "== SKIPPED (${#SKIPPED[@]})"
  if ((${#SKIPPED[@]})); then printf '  %s\n' "${SKIPPED[@]}"; fi
}

# SHA-256 tool detection (portable): sha256sum, or shasum -a 256 on
# macOS. A tool is accepted only if it actually works on a probe; the
# output is normalized to the hash field only. On success the global
# SHA_TOOL_USED records which tool produced the hash.
SHA_TOOL_USED=
sha256_of() { # sha256_of <file> -> hash, non-zero exit if no tool
  local _h
  if command -v sha256sum >/dev/null 2>&1; then
    _h=$(sha256sum "$1" 2>/dev/null) &&
      { printf '%s\n' "${_h%% *}"; SHA_TOOL_USED=sha256sum; return 0; }
  fi
  if command -v shasum >/dev/null 2>&1; then
    _h=$(shasum -a 256 "$1" 2>/dev/null) &&
      { printf '%s\n' "${_h%% *}"; SHA_TOOL_USED=shasum; return 0; }
  fi
  return 1
}

checksum_guard() {
  [[ ! -f $MK/manifest.yaml ]] && return 0
  [[ -f $MK/manifest.yaml.checksum ]] || {
    echo "CHECKSUM_MISSING: .manifest/manifest.yaml.checksum not found"
    exit 1
  }
  local expected actual
  expected=$(sed 's/^[^:]*://' "$MK/manifest.yaml.checksum")
  actual=$(sha256_of "$MK/manifest.yaml")
  [[ $actual == "$expected" ]] || {
    echo "CHECKSUM_MISMATCH: .manifest/manifest.yaml does not match its protection record"
    exit 1
  }
}

preflight() {
  local fails=()
  command -v git >/dev/null 2>&1 ||
    fails+=("git not available in PATH — install Git")
  git -C "$PROJECT" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    fails+=("project is not inside a Git work tree — run 'git init' in the project first")
  # Write probe with a unique name: a pre-existing user file named
  # .manifest-write-probe can never be overwritten or removed.
  local probe
  probe=$(mktemp "$PROJECT/.manifest-write-probe.XXXXXX" 2>/dev/null) &&
    rm -f "$probe" ||
    fails+=("project root is not writable — grant write permission to the project root")
  [[ -e $MK ]] &&
    fails+=("REINIT_REFUSED: .manifest already exists — the project is already initialized; re-initialization is not provided")
  [[ -d $TEMPLATES && -r $TEMPLATES ]] ||
    fails+=("template source unavailable or not readable: $TEMPLATES — pass --templates pointing to the Manifest docs/templates directory")
  if ! command -v perl >/dev/null 2>&1 || ! perl -e 'exit 0' >/dev/null 2>&1; then
    fails+=("Perl is required for template rendering but is not available in PATH — install Perl and retry")
  fi
  if ! sha256_of "$0" >/dev/null 2>&1; then
    fails+=("no working SHA-256 tool in PATH — install coreutils (sha256sum) or Perl's shasum")
  fi
  if ((${#fails[@]})); then
    echo "PREFLIGHT FAIL (${#fails[@]} check(s)):"
    printf '  - %s\n' "${fails[@]}"
    exit 1
  fi
}

write_config() {
  mkdir -p "$MK"
  local tmp=$MK/manifest.yaml.tmp
  {
    echo "project_name=$PROJECT_NAME"
    echo "tracks=$TRACKS"
    echo "created=$(date +%F)"
  } >"$tmp"
  mv "$tmp" "$MK/manifest.yaml"
  # The checksum records the SHA-256 tool that produced it:
  # "<tool>:<hash>"; the guard extracts the hash after the prefix.
  sha256_of "$MK/manifest.yaml" >/dev/null
  printf '%s:%s\n' "$SHA_TOOL_USED" "$(sha256_of "$MK/manifest.yaml")" \
    >"$MK/manifest.yaml.checksum"
}

# Name-mapping table (design D4): installed file <- source template.
BASE_NAMES=(AGENTS.md llms.txt COMMIT_RULES.md VERSION VERSIONING.md)
BASE_SOURCES=(agents.template.md llm.template.txt commit-rules.template.md version.template versioning.template.md)

# Render a template per the placeholder policy (design D7):
# conditional blocks render through the templates' own fallback
# branches (ENTRY_POINT / BUILD_METHOD stay empty), then variables
# are substituted from interview data or deterministic defaults.
render_template() {
  local src=$1 dst=$2
  PROJECT_NAME="$PROJECT_NAME" PURPOSE="$PURPOSE" \
    INITIAL_VERSION="$INITIAL_VERSION" \
    perl -pe '
      s/\{%\s*if\s+\w+\s*%\}(.*?)\{%\s*else\s*%\}(.*?)\{%\s*endif\s*%\}/$2/gs;
      s/\{%\s*if\s+\w+\s*%\}.*?\{%\s*endif\s*%\}//gs;
      s/\{\{PROJECT_NAME\}\}/$ENV{PROJECT_NAME}/g;
      s/\{\{PROJECT_PURPOSE\}\}/$ENV{PURPOSE}/g;
      s/\{\{INITIAL_VERSION\}\}/$ENV{INITIAL_VERSION}/g;
      s/\{\{PROJECT_CONTEXT\}\}/Not established./g;
      s/\{\{PROJECT_DIRECTORIES\}\}/Not established./g;
    ' "$src" >"$dst"
}

# INSTALL_CORRUPT handler (design D7 rollback note): the file is not
# installed, files created by THIS run are removed, pre-existing files
# are never touched, the full report is printed before exit.
install_corrupt() {
  local msg=$1 tmpdir=$2 f
  echo "INSTALL_CORRUPT $msg"
  report
  for f in "${INSTALLED[@]}"; do
    rm -f "$PROJECT/$f"
  done
  rm -rf "$MK" "$tmpdir"
  echo "INSTALL CORRUPT: files created by this run were removed; pre-existing files untouched"
  exit 1
}

install_templates() {
  local i name src rendered
  local tmpdir
  tmpdir=$(mktemp -d)
  for i in "${!BASE_NAMES[@]}"; do
    name=${BASE_NAMES[$i]}
    src=$TEMPLATES/${BASE_SOURCES[$i]}
    if [[ -e $PROJECT/$name ]]; then
      CONFLICTS+=("$name")
      continue
    fi
    rendered=$tmpdir/$name
    if ! render_template "$src" "$rendered"; then
      install_corrupt "$name (render failed)" "$tmpdir"
    fi
    # A file with a leftover placeholder is never installed.
    if grep -q -e '{{' -e '{%' "$rendered"; then
      install_corrupt "$name (unresolved placeholder)" "$tmpdir"
    fi
    cp "$rendered" "$PROJECT/$name"
    cmp -s "$rendered" "$PROJECT/$name" ||
      install_corrupt "$name (installed file differs from render)" "$tmpdir"
    INSTALLED+=("$name")
  done
  rm -rf "$tmpdir"
  report
  if ((${#CONFLICTS[@]})); then
    echo "INIT DONE WITH CONFLICTS (${#CONFLICTS[@]})"
    exit 3
  fi
  echo "INIT OK"
}

checksum_guard
preflight
interview
write_config
install_templates
