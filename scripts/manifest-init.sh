#!/usr/bin/env bash
# manifest-init.sh — initialize Manifest in a project (MVP stage 1).
# Usage:
#   manifest-init.sh --templates <dir> [--project <dir>]
#                    [--project-name <name>]
#                    [--tracks none|code|documentation|mixed]
# Exit codes: 0 OK, 2 usage, 3 conflicts, 1 preflight/guard failure.
set -euo pipefail

PROJECT=.
TEMPLATES=
PROJECT_NAME=
TRACKS=
ASK_NAME=0
ASK_TRACKS=0

usage() {
  echo "usage: manifest-init.sh --templates <dir> [--project <dir>] [--project-name <name>] [--tracks none|code|documentation|mixed]"
  exit 2
}

while (($#)); do
  case "$1" in
    --project) PROJECT=$2; shift 2 ;;
    --templates) TEMPLATES=$2; shift 2 ;;
    --project-name) PROJECT_NAME=$2; shift 2 ;;
    --tracks) TRACKS=$2; shift 2 ;;
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
  find "$PROJECT" -maxdepth 3 -path "$PROJECT/.manifest" -prune -o \
    -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.cs' -o \
    -name '*.go' -o -name '*.java' -o -name '*.js' -o -name '*.py' -o \
    -name '*.rs' -o -name '*.sh' -o -name '*.ts' \) -print -quit |
    grep -q . && has_code=1
  [[ -d $PROJECT/docs ]] && has_docs=1
  if ((has_code && has_docs)); then echo mixed
  elif ((has_code)); then echo code
  elif ((has_docs)); then echo documentation
  else echo none
  fi
}

interview() {
  local proposed
  proposed=$(analyze_project)
  if [[ -z $PROJECT_NAME ]]; then
    ASK_NAME=1
    printf 'Project name [%s]: ' "$(basename "$PROJECT")"
    read -r PROJECT_NAME
    [[ -n $PROJECT_NAME ]] || PROJECT_NAME=$(basename "$PROJECT")
  fi
  if [[ -z $TRACKS ]]; then
    ASK_TRACKS=1
    printf 'Tracks — proposed: %s [confirm/change] (none|code|documentation|mixed): ' "$proposed"
    read -r TRACKS
    case $TRACKS in
      code | documentation | mixed | none) ;;
      *) TRACKS=$proposed ;;
    esac
  fi
}

INSTALLED=()
CONFLICTS=()
SKIPPED=()

report() {
  echo "== CONFIG"
  sed 's/^/  /' "$MK/manifest.yaml"
  echo "== INSTALLED (${#INSTALLED[@]})"
  ((${#INSTALLED[@]})) && printf '  %s\n' "${INSTALLED[@]}"
  echo "== CONFLICTS (${#CONFLICTS[@]})"
  ((${#CONFLICTS[@]})) && printf '  %s\n' "${CONFLICTS[@]}"
  echo "== SKIPPED (${#SKIPPED[@]})"
  ((${#SKIPPED[@]})) && printf '  %s\n' "${SKIPPED[@]}"
}

checksum_guard() {
  [[ ! -f $MK/manifest.yaml ]] && return 0
  [[ -f $MK/manifest.yaml.checksum ]] || {
    echo "CHECKSUM_MISSING: .manifest/manifest.yaml.checksum not found"
    exit 1
  }
  local expected actual
  expected=$(awk '{print $1}' "$MK/manifest.yaml.checksum")
  actual=$( (cd "$MK" && sha256sum manifest.yaml) | awk '{print $1}' )
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
  if ! ( : >"$PROJECT/.manifest-write-probe" ) 2>/dev/null; then
    fails+=("project root is not writable — grant write permission to the project root")
  else
    rm -f "$PROJECT/.manifest-write-probe"
  fi
  [[ -e $MK ]] &&
    fails+=(".manifest already exists — the project is already initialized; re-initialization is not provided")
  [[ -d $TEMPLATES && -r $TEMPLATES ]] ||
    fails+=("template source unavailable or not readable: $TEMPLATES — pass --templates pointing to the Manifest docs/templates directory")
  command -v sha256sum >/dev/null 2>&1 ||
    fails+=("sha256sum not available in PATH — install coreutils/sha256sum")
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
  ( cd "$MK" && sha256sum manifest.yaml > manifest.yaml.checksum )
}

checksum_guard
preflight
interview
write_config
report
echo "INIT OK"
