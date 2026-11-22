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
# shellcheck source=verify.sh
source "$ROOT/scripts/verify.sh"
FAILS=()
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
mkdir -p "$TMP/scope" "$TMP/empty-scripts"
printf '# clean file\n' >"$TMP/scope/clean.md"

# 1. Clean tree passes.
run_check "clean-scope-passes" "$TMP/scope" "$TMP/empty-scripts" 0

# 2. Machine path (Windows drive letter).
printf 'path C:\\Users\\someone\\x\n' >"$TMP/scope/v1.md"
run_check "machine-path-caught" "$TMP/scope" "$TMP/empty-scripts" 1 "C:"
rm -f "$TMP/scope/v1.md"

# 3. Unix home path.
printf 'see /home/someone/x\n' >"$TMP/scope/v2.md"
run_check "home-path-caught" "$TMP/scope" "$TMP/empty-scripts" 1 "/home/"
rm -f "$TMP/scope/v2.md"

# 4. Personal email.
printf 'mail: person@example.com\n' >"$TMP/scope/v3.md"
run_check "email-caught" "$TMP/scope" "$TMP/empty-scripts" 1 "@"
rm -f "$TMP/scope/v3.md"

# 5. Unrelated project mention.
printf 'uses handy-dictation-scrubber\n' >"$TMP/scope/v4.md"
run_check "foreign-project-caught" "$TMP/scope" "$TMP/empty-scripts" 1 "handy"
rm -f "$TMP/scope/v4.md"

# 6. Model/harness-specific detail (non-workflow scope).
printf 'model: Qwen3.8-27B\n' >"$TMP/scope/v5.md"
run_check "model-name-caught" "$TMP/scope" "$TMP/empty-scripts" 1 "Qwen"
rm -f "$TMP/scope/v5.md"

# 7. Allowlist marker exempts a line.
printf 'path C:\\Users\\someone\\x # portability-allow\n' >"$TMP/scope/v6.md"
run_check "allow-marker-exempts" "$TMP/scope" "$TMP/empty-scripts" 0
rm -f "$TMP/scope/v6.md"

# 7a. A paired RU/EN document passes.
mkdir -p "$TMP/pairs"
printf 'Russian\n' >"$TMP/pairs/sample.ru.md"
printf 'English\n' >"$TMP/pairs/sample.en.md"
run_check "paired-ru-en-passes" "$TMP/pairs" "$TMP/empty-scripts" 0
rm -rf "$TMP/pairs"

# 7b. An English edition without RU is rejected.
mkdir -p "$TMP/pairs"
printf 'English\n' >"$TMP/pairs/sample.en.md"
run_check "english-without-russian-caught" "$TMP/pairs" "$TMP/empty-scripts" 1 "without Russian sibling"
rm -rf "$TMP/pairs"

# 7c. A Russian edition without EN is rejected.
mkdir -p "$TMP/pairs"
printf 'Russian\n' >"$TMP/pairs/sample.ru.md"
run_check "russian-without-english-caught" "$TMP/pairs" "$TMP/empty-scripts" 1 "without English sibling"
rm -rf "$TMP/pairs"

# 8. Undeclared external binary in a seeded script. The seed binary
# must resolve on this machine (unresolvable names are skipped by
# design); pick the first available undeclared candidate.
seed_bin=
for cand in python python3 seq unlink; do
  if command -v "$cand" >/dev/null 2>&1; then seed_bin=$cand; break; fi
done
mkdir -p "$TMP/scripts"
cp "$ROOT/scripts/structure-parser.sh" "$TMP/scripts/" 2>/dev/null
if [[ -n $seed_bin ]]; then
  printf '%s -c "x"\n' "$seed_bin" >"$TMP/scripts/seeded.sh"
  run_check "undeclared-binary-caught" "$TMP/scope" "$TMP/scripts" 1 "$seed_bin"
else
  deny "undeclared-binary-caught: no executable candidate available"
fi

# 9. Real repo: autonomy passes end to end and the human-review
# routing line appears in verify.sh output.
vout=$(bash "$ROOT/scripts/verify.sh" 2>&1) && vrc=0 || vrc=$?
if ((vrc == 0)) &&
   grep -q 'human review' <<<"$vout" &&
   grep -q 'shell dependencies outside' <<<"$vout"; then
  note "real-repo-passes"
else
  deny "real-repo-passes: exit $vrc / ${FAILS[*]} / output: $vout"
fi

# 10. Registered binary in a seeded script is not flagged.
rm -f "$TMP/scripts/seeded.sh"
printf 'grep -q x "$1"\n' >"$TMP/scripts/declared.sh"
run_check "declared-binary-accepted" "$TMP/scope" "$TMP/scripts" 0

scope_listing=$(autonomy_scope)
if grep -Fxq "$ROOT/docs/manifest.compact.md" <<<"$scope_listing" &&
   grep -Fxq "$ROOT/VERSION" <<<"$scope_listing" &&
   ! grep -Fq "$ROOT/workflow/universal-comment-rules.en.md" <<<"$scope_listing"; then
  note "current-scope-is-correct"
else
  deny "current-scope-is-correct: compact manifest missing or workflow scanned"
fi

fake_root="$TMP/fake-root"
mkdir -p "$fake_root/scripts" "$fake_root/docs/templates" "$fake_root/openspec/specs" "$fake_root/workflow"
printf 'BASE_SOURCES=(agents.template.md workflow/agent-rules.en.md)\n' >"$fake_root/scripts/manifest-init.sh"
printf 'template\n' >"$fake_root/docs/templates/agents.template.md"
printf 'non-Markdown template\n' >"$fake_root/docs/templates/custom.template"
printf 'English\n' >"$fake_root/workflow/agent-rules.en.md"
printf 'Russian\n' >"$fake_root/workflow/agent-rules.ru.md"
git -C "$fake_root" init -q
git -C "$fake_root" add .
saved_root=$ROOT
ROOT=$fake_root
future_scope=$(autonomy_scope)
ROOT=$saved_root
if grep -Fxq "$fake_root/workflow/agent-rules.en.md" <<<"$future_scope" &&
   grep -Fxq "$fake_root/docs/templates/custom.template" <<<"$future_scope"; then
  note "distributed-source-enters-scope"
else
  deny "distributed-source-enters-scope: distributed source or non-Markdown template not included"
fi

# 14. Avoid GNU-only utility options in scripts intended for macOS.
if grep -nE 'find .*-(maxdepth|mindepth|quit)([[:space:]]|$)' "$ROOT"/scripts/*.sh "$ROOT"/scripts/hooks/*; then
  deny "macos-find-options-portable: GNU-only find option found"
else
  note "macos-find-options-portable"
fi
if grep -nE 'head[[:space:]]+-n[[:space:]]+-[0-9]+' "$ROOT"/scripts/*.sh "$ROOT"/scripts/hooks/*; then
  deny "macos-head-options-portable: GNU-only head option found"
else
  note "macos-head-options-portable"
fi

if [[ -n $seed_bin ]]; then
  printf 'printf ok && %s -c x\n' "$seed_bin" >"$TMP/scripts/compound.sh"
  run_check "compound-command-caught" "$TMP/scope" "$TMP/scripts" 1 "$seed_bin"
  rm -f "$TMP/scripts/compound.sh"
  mkdir -p "$TMP/scripts/hooks"
  printf '#!/usr/bin/env bash\n%s -c x\n' "$seed_bin" >"$TMP/scripts/hooks/pre-commit"
  run_check "extensionless-hook-caught" "$TMP/scope" "$TMP/scripts" 1 "$seed_bin"
  rm -f "$TMP/scripts/hooks/pre-commit"
else
  deny "compound-command-caught: no executable candidate available"
  deny "extensionless-hook-caught: no executable candidate available"
fi

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
((${#FAIL[@]})) && exit 1
exit 0
