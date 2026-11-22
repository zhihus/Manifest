#!/usr/bin/env bash
# Regression tests for structure-parser.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PARSER="$ROOT/scripts/structure-parser.sh"
TMP_ROOT="$ROOT/temp"
mkdir -p "$TMP_ROOT"
WORK="$(mktemp -d "$TMP_ROOT/structure-parser.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

assert_status() {
  local expected="$1" actual output
  shift
  set +e
  output="$(bash "$PARSER" "$@" 2>&1)"
  actual=$?
  set -e
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: expected exit %s, got %s: %s\n%s\n' "$expected" "$actual" "$*" "$output" >&2
  fi
  printf '%s' "$output"
}

assert_contains() {
  local haystack="$1" needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL: output does not contain: %s\nActual output:\n%s\n' "$needle" "$haystack" >&2
  fi
}

write_valid() {
  cat > "$1" <<'DOC'
# Test Document

# Metadata
> **Status: draft**  
> **Type: document**  
> **Version: 1.0.0**  
> **Updated: 2026-11-22**  

# Description
A valid test document.

## 1. Rules

### 1.1. First rule
DOC
}

mkdir -p "$WORK/input/nested folder" "$WORK/empty"
write_valid "$WORK/input/valid.md"
write_valid "$WORK/input/nested folder/valid nested.md"
write_valid "$WORK/input/nested folder/special & name.md"
if ln -s "$WORK/input/valid.md" "$WORK/input/nested folder/linked.md" 2>/dev/null; then
  : # Symlink is intentionally excluded by the directory walker.
fi

# Existing single-file mode remains supported.
assert_status 0 "$WORK/input/valid.md" >/dev/null

# Recursive mode discovers root and nested Markdown files, including spaces.
set +e
output="$(bash "$PARSER" --dir "$WORK/input" 2>&1)"
status=$?
set -e
if [[ "$status" == 0 ]]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); fi
assert_contains "$output" "Markdown files checked: 3"

# Two independent violations must both be reported in one directory run.
sed 's/Status: draft/Status: invalid/' "$WORK/input/valid.md" > "$WORK/input/invalid root.md"
sed 's/Version: 1.0.0/Version: invalid/' "$WORK/input/nested folder/valid nested.md" > "$WORK/input/nested folder/invalid nested.md"
set +e
output="$(bash "$PARSER" --dir "$WORK/input" 2>&1)"
status=$?
set -e
if [[ "$status" == 1 ]]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); fi
assert_contains "$output" "invalid root.md"
assert_contains "$output" "invalid nested.md"
assert_contains "$output" "Markdown files checked: 5"

# A single invalid file still returns 1.
assert_status 1 "$WORK/input/invalid root.md" >/dev/null

# Empty, missing, and malformed directory invocations are usage errors.
assert_status 2 --dir "$WORK/empty" >/dev/null
assert_status 2 --dir "$WORK/missing" >/dev/null
assert_status 2 --dir >/dev/null

printf 'Structure parser tests: %s passed, %s failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
