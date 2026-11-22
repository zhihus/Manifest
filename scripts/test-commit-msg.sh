#!/usr/bin/env bash
# Regression tests for scripts/hooks/commit-msg.
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
HOOK=$ROOT/scripts/hooks/commit-msg
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=()
FAIL=()

run_case() {
  local label=$1 expected=$2 message=$3 actual
  printf '%s' "$message" > "$TMP/message"
  cp "$TMP/message" "$TMP/original"
  if bash "$HOOK" "$TMP/message" >/dev/null 2>&1; then
    actual=0
  else
    actual=$?
  fi
  if [[ $actual -eq $expected ]]; then
    if cmp -s "$TMP/message" "$TMP/original"; then
      PASS+=("$label")
    else
      FAIL+=("$label: hook modified the message")
    fi
  else
    FAIL+=("$label: exit $actual, expected $expected")
  fi
}

run_case valid-scoped 0 $'feat(audio-capture): add noise gate\n'
run_case valid-unscoped 0 $'docs: update readme\n'
run_case valid-long-soft-limit 0 $'chore: document the complete verification and commit workflow\n'
run_case invalid-type 1 $'unknown: add feature\n'
run_case invalid-format 1 $'feat add feature\n'
run_case uppercase-subject 1 $'feat: Add feature\n'
run_case non-english-subject 1 $'feat: добавить функцию\n'
run_case empty-subject 1 $'feat: \n'
run_case trailing-period 1 $'fix: handle empty input.\n'
run_case invalid-scope 1 $'feat(Audio): add feature\n'
run_case valid-breaking 0 $'fix(parser)!: handle empty input\n\nBREAKING CHANGE: reject malformed payloads\n'
run_case missing-breaking-footer 1 $'fix(parser)!: handle empty input\n'
run_case footer-without-marker 1 $'fix(parser): handle empty input\n\nBREAKING CHANGE: change parser contract\n'
run_case empty-breaking-footer 1 $'fix(parser)!: handle empty input\n\nBREAKING CHANGE:   \n'

if bash "$HOOK" >/dev/null 2>&1; then
  FAIL+=("missing-argument: unexpectedly accepted")
else
  rc=$?
  [[ $rc -eq 2 ]] && PASS+=("missing-argument") || FAIL+=("missing-argument: exit $rc, expected 2")
fi

printf 'RESULTS: %s passed, %s failed\n' "${#PASS[@]}" "${#FAIL[@]}"
printf 'PASS %s\n' "${PASS[@]}"
printf 'FAIL %s\n' "${FAIL[@]}"
(("${#FAIL[@]}" == 0))
