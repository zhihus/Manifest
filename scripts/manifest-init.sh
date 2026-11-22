#!/usr/bin/env bash
# manifest-init.sh — initialize Manifest in a project (MVP stage 1).
# Usage:
#   manifest-init.sh --templates <dir> [--project <dir>]
# Exit codes: 0 OK, 2 usage, 3 conflicts, 1 preflight/guard failure.
set -euo pipefail

PROJECT=.
TEMPLATES=
PROJECT_NAME=unnamed
TRACKS=none

usage() {
  echo "usage: manifest-init.sh --templates <dir> [--project <dir>] [--tracks none|code|documentation|mixed]"
  exit 2
}

while (($#)); do
  case "$1" in
    --project) PROJECT=$2; shift 2 ;;
    --templates) TEMPLATES=$2; shift 2 ;;
    --tracks) TRACKS=$2; shift 2 ;;
    *) usage ;;
  esac
done
[[ -n $TEMPLATES ]] || usage

MK=$PROJECT/.manifest

preflight() {
  [[ -d $TEMPLATES && -r $TEMPLATES ]] || {
    echo "PREFLIGHT FAIL: template source unavailable: $TEMPLATES"
    exit 1
  }
  [[ ! -e $MK ]] || {
    echo "REINIT_REFUSED: .manifest already exists; re-initialization is not provided"
    exit 1
  }
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

preflight
write_config
echo "INIT OK"
