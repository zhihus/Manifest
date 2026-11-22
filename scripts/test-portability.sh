#!/usr/bin/env bash
# test-portability.sh — mechanical verification of the autonomy and
# privacy checks in verify.sh (portability-principles, FR 5.1).
# Usage: bash scripts/test-portability.sh
# Exit codes: 0 all checks pass, 1 at least one fails.
set -uo pipefail

ROOT=$(git rev-parse --show-toplevel)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=()
FAIL=()

note() { printf 'PASS %s\n' "$1"; PASS+=("$1"); }
deny() { printf 'FAIL %s\n' "$1"; FAIL+=("$1"); }

# check_autonomy is sourced from verify.sh: it accepts scope-dir and
# scripts-dir overrides for fixture testing and appends to FAILS.
# shellcheck disable=SC1090
FAILS=()
fail() { FAILS+=("verify.sh: FAIL: $1"); }
VERIFY_FUNCS=$(sed -n '/^# --- autonomy checks/,/^# --- 4\. main/p' \
  "$ROOT/scripts/verify.sh" | sed '$d')
eval "$VERIFY_FUNCS"

run_check() { # run_check <label> <scope-dir> <scripts-dir> <expect:0|1> <pattern>
  local label=$1 scope=$2 scripts=$3 expect=$4 pattern=${5:-}
  FAILS=()
  check_autonomy "$scope" "$scripts" >/dev/null 2>&1
  local out="${FAILS[*]}"
  if [[ $expect == 0 ]]; then
    if ((${#FAILS[@]} == 0)); then note "$label"; else deny "$label (unexpected: $out)"; fi
  else
    if ((${#FAILS[@]} > 0)) && grep -q "$pattern" <<<"$out"; then
      note "$label"
    else
      deny "$label (expected violation '$pattern', got: $out)"
    fi
  fi
}

# Fixture scope: one benign public file.
mkdir -p "$TMP/scope"
printf '# clean file\n' >"$TMP/scope/clean.md"

# 1. Clean tree passes.
run_check "clean-scope-passes" "$TMP/scope" "$ROOT/scripts" 0

# 2. Machine path (Windows drive letter).
printf 'path C:\\Users\\someone\\x\n' >"$TMP/scope/v1.md"
run_check "machine-path-caught" "$TMP/scope" "$ROOT/scripts" 1 "C:"
rm -f "$TMP/scope/v1.md"

# 3. Unix home path.
printf 'see /home/someone/x\n' >"$TMP/scope/v2.md"
run_check "home-path-caught" "$TMP/scope" "$ROOT/scripts" 1 "/home/"
rm -f "$TMP/scope/v2.md"

# 4. Personal email.
printf 'mail: person@example.com\n' >"$TMP/scope/v3.md"
run_check "email-caught" "$TMP/scope" "$ROOT/scripts" 1 "@"
rm -f "$TMP/scope/v3.md"

# 5. Unrelated project mention.
printf 'uses handy-dictation-scrubber\n' >"$TMP/scope/v4.md"
run_check "foreign-project-caught" "$TMP/scope" "$ROOT/scripts" 1 "handy"
rm -f "$TMP/scope/v4.md"

# 6. Model/harness-specific detail (non-workflow scope).
printf 'model: Qwen3.8-27B\n' >"$TMP/scope/v5.md"
run_check "model-name-caught" "$TMP/scope" "$ROOT/scripts" 1 "Qwen"
rm -f "$TMP/scope/v5.md"

# 7. Allowlist marker exempts a line.
printf 'path C:\\Users\\someone\\x # portability-allow\n' >"$TMP/scope/v6.md"
run_check "allow-marker-exempts" "$TMP/scope" "$ROOT/scripts" 0
rm -f "$TMP/scope/v6.md"

# 8. Undeclared external binary in a seeded script. The seed binary
# must resolve on this machine (unresolvable names are skipped by
# design); pick the first available undeclared candidate.
seed_bin=
for cand in python python3 seq unlink; do
  if command -v "$cand" >/dev/null 2>&1; then seed_bin=$cand; break; fi
done
mkdir -p "$TMP/scripts"
cp "$ROOT/scripts/structure-parser.sh" "$TMP/scripts/" 2>/dev/null
printf '%s -c "x"\n' "${seed_bin:-python}" >"$TMP/scripts/seeded.sh"
run_check "undeclared-binary-caught" "$TMP/scope" "$TMP/scripts" 1 "${seed_bin:-python}"

# 9. Real repo: autonomy passes end to end and the human-review
# routing line appears in verify.sh output.
FAILS=()
check_autonomy >/dev/null 2>&1
vout=$(bash "$ROOT/scripts/verify.sh" 2>&1 || true)
if ((${#FAILS[@]} == 0)) && grep -q 'human review' <<<"$vout"; then
  note "real-repo-passes"
else
  deny "real-repo-passes: ${FAILS[*]} / output: $vout"
fi

# 10. Registered binary in a seeded script is not flagged.
rm -f "$TMP/scripts/seeded.sh"
printf 'grep -q x "$1"\n' >"$TMP/scripts/declared.sh"
run_check "declared-binary-accepted" "$TMP/scope" "$TMP/scripts" 0

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
((${#FAIL[@]})) && exit 1
exit 0
