#!/usr/bin/env bash
# Tests for resolve-todoing.sh: resolution priority and version verification.
#
# Priority under test:
#   1. explicit TODOING_BIN
#   2. portable build in the release cache
#   3. `todoing` on PATH
#
# Also verified: an incompatible version is a hard stop, and a TODOING_BIN
# pointing to a missing file is a hard stop (no silent fallback).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RESOLVER="$ROOT/scripts/resolve-todoing.sh"
FAIL=0

fail() {
  printf 'FAIL %s\n' "$1"
  FAIL=1
}

# Isolated scratch space (left in the system temp folder, never deleted).
TESTDIR=$(mktemp -d)

# Fake binaries: shell scripts that report a fixed version.
GOOD="$TESTDIR/todoing-good"
BAD="$TESTDIR/todoing-bad"
printf '#!/usr/bin/env bash\nif [[ "${1:-}" == version ]]; then echo 1.2.0; fi\n' > "$GOOD"
printf '#!/usr/bin/env bash\nif [[ "${1:-}" == version ]]; then echo 0.9.9; fi\n' > "$BAD"
chmod +x "$GOOD" "$BAD"

# Fake release cache with an extracted portable package.
CACHE="$TESTDIR/cache"
PORTABLE_DIR="$CACHE/portable/1.2.0/windows-x64"
mkdir -p "$PORTABLE_DIR"
cp "$GOOD" "$PORTABLE_DIR/todoing.exe"
chmod +x "$PORTABLE_DIR/todoing.exe"

# Second cache containing an incompatible portable build.
BADCACHE="$TESTDIR/badcache"
BADPORTABLE_DIR="$BADCACHE/portable/1.2.0/windows-x64"
mkdir -p "$BADPORTABLE_DIR"
cp "$BAD" "$BADPORTABLE_DIR/todoing.exe"
chmod +x "$BADPORTABLE_DIR/todoing.exe"

# Fake PATH entry containing a `todoing` on PATH.
PATHBIN="$TESTDIR/pathbin"
mkdir -p "$PATHBIN"
cp "$GOOD" "$PATHBIN/todoing"
chmod +x "$PATHBIN/todoing"

MINPATH="/usr/bin:/bin"

# Run the resolver in a clean environment with only the given variables.
run_resolver() {
  env -i PATH="$MINPATH" "$@" bash "$RESOLVER"
}

expect_path() {
  local label=$1 expected=$2
  shift 2
  local actual
  if ! actual=$(run_resolver "$@"); then
    fail "$label: resolver exited non-zero (expected success)"
    return
  fi
  if [[ $actual != "$expected" ]]; then
    fail "$label: resolved '$actual', expected '$expected'"
  else
    printf 'PASS %s\n' "$label"
  fi
}

expect_fail() {
  local label=$1
  shift
  if run_resolver "$@" >/dev/null 2>&1; then
    fail "$label: resolver succeeded (expected failure)"
  else
    printf 'PASS %s\n' "$label"
  fi
}

# --- Priority 1: explicit TODOING_BIN wins over cache and PATH -------------
expect_path "priority: TODOING_BIN wins over cache and PATH" "$GOOD" \
  "TODOING_BIN=$GOOD" "TODOING_CACHE_DIR=$CACHE" "PATH=$PATHBIN:$MINPATH"

# --- Priority 2: portable cache wins over PATH ------------------------------
expect_path "priority: portable cache wins over PATH" "$PORTABLE_DIR/todoing.exe" \
  "TODOING_CACHE_DIR=$CACHE" "PATH=$PATHBIN:$MINPATH"

# --- Priority 3: PATH fallback ----------------------------------------------
expect_path "priority: PATH fallback" "$PATHBIN/todoing" \
  "PATH=$PATHBIN:$MINPATH"

# --- Incompatible version is a hard stop ------------------------------------
expect_fail "incompatible version via TODOING_BIN is rejected" \
  "TODOING_BIN=$BAD"
expect_fail "incompatible version in cache is rejected" \
  "TODOING_CACHE_DIR=$BADCACHE"

# --- Misconfigured TODOING_BIN is a hard stop (no silent fallback) ----------
expect_fail "TODOING_BIN pointing to a missing file is rejected" \
  "TODOING_BIN=$TESTDIR/does-not-exist" "PATH=$PATHBIN:$MINPATH"

# --- Nothing available -------------------------------------------------------
expect_fail "no binary anywhere is rejected" \
  "PATH=$MINPATH"

if (( FAIL )); then
  exit 1
fi
echo "OK: resolve-todoing.sh priority and verification tests passed"