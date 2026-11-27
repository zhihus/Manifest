#!/usr/bin/env bash
# Resolve the Todoing binary for Manifest, in strict priority order:
#
#   1. Explicit TODOING_BIN (must point to an existing file)
#   2. Portable build in the Manifest release cache
#      (<cache>/portable/<VERSION>/<PLATFORM>-<ARCH>/todoing[.exe])
#   3. `todoing` found on PATH
#
# After resolution the binary's reported version is verified against
# TODOING_REQUIRED_VERSION (default: 1.2.0). An incompatible version is a
# hard stop — the resolver never silently falls back to another binary.
#
# On success the resolved absolute path is printed on stdout, so the result
# can be used as:  TODOING_BIN=$(bash scripts/resolve-todoing.sh)
#
# Environment:
#   TODOING_BIN                explicit binary path (highest priority)
#   TODOING_CACHE_DIR          release cache root (default: <Manifest>/.todoing-cache)
#   TODOING_REQUIRED_VERSION   required version (default: 1.2.0)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
REQUIRED=${TODOING_REQUIRED_VERSION:-1.2.0}
CACHE=${TODOING_CACHE_DIR:-$ROOT/.todoing-cache}

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- Platform / arch detection (same convention as the Todoing build) -----
OS_RAW=$(uname -s)
case "$OS_RAW" in
  Linux) PLATFORM=linux ;;
  Darwin) PLATFORM=macos ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM=windows ;;
  *) fail "unsupported OS: $OS_RAW" ;;
esac
ARCH_RAW=$(uname -m)
case "$ARCH_RAW" in
  x86_64|amd64) ARCH=x64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) fail "unsupported arch: $ARCH_RAW" ;;
esac
PLATFORM_ARCH="${PLATFORM}-${ARCH}"
[[ $PLATFORM == windows ]] && EXE=".exe" || EXE=""

# --- Resolution ------------------------------------------------------------
BIN=""
SOURCE=""
if [[ -n ${TODOING_BIN:-} ]]; then
  [[ -f $TODOING_BIN ]] || fail "TODOING_BIN is set but does not exist: $TODOING_BIN"
  BIN=$TODOING_BIN
  SOURCE="TODOING_BIN"
else
  PORTABLE_BIN="$CACHE/portable/$REQUIRED/$PLATFORM_ARCH/todoing$EXE"
  if [[ -f $PORTABLE_BIN ]]; then
    BIN=$PORTABLE_BIN
    SOURCE="portable cache"
  else
    FOUND=$(command -v todoing 2>/dev/null || true)
    if [[ -n $FOUND ]]; then
      BIN=$FOUND
      SOURCE="PATH"
    else
      fail "no Todoing binary found. Set TODOING_BIN, place a portable build at $PORTABLE_BIN, or put 'todoing' on PATH."
    fi
  fi
fi

# --- Version / compatibility verification (before any store operation) ----
VERSION=$("$BIN" version 2>/dev/null || echo "<unavailable>")
if [[ $VERSION != "$REQUIRED" ]]; then
  fail "incompatible Todoing version: got '$VERSION', required '$REQUIRED' (source: $SOURCE, binary: $BIN)"
fi

echo "$BIN"