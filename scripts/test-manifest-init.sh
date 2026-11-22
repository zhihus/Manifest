#!/usr/bin/env bash
# test-manifest-init.sh — mechanical verification of manifest-init.sh
# against the four fixture scenarios of add-manifest-init-mvp (FR 4.1).
# Usage: bash scripts/test-manifest-init.sh
# Exit codes: 0 all fixtures pass, 1 at least one fixture fails.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
INIT=$HERE/manifest-init.sh
TEMPLATES=$(cd "$HERE/.." && pwd)/docs/templates
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=()
FAIL=()

assert() { # assert <label> <expected-exit> <fixture-dir> <pattern...>
  local label=$1 want=$2 dir=$3; shift 3
  local out rc
  out=$(bash "$INIT" --templates "$TEMPLATES" --project "$dir" \
    --project-name demo --tracks code 2>&1)
  rc=$?
  local ok=1
  [[ $rc -eq $want ]] || { ok=0; FAIL+=("$label: exit $rc != $want"); }
  local p
  for p in "$@"; do
    if [[ $p == !* ]]; then
      grep -q "${p#!}" <<<"$out" && { ok=0; FAIL+=("$label: unexpected '${p#!}'"); }
    else
      grep -q "$p" <<<"$out" || { ok=0; FAIL+=("$label: missing '$p'"); }
    fi
  done
  if ((ok)); then PASS+=("$label"); fi
}

# Fixture 1: fresh Git project without context files.
mkdir -p "$TMP/fresh" && git -C "$TMP/fresh" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("fresh: exit $rc != 0"); }
for f in AGENTS.md llms.txt COMMIT_RULES.md VERSION VERSIONING.md; do
  [[ -f $TMP/fresh/$f ]] || { ok=0; FAIL+=("fresh: $f not installed"); }
done
n=$(grep -c '^  ' <<<"$(sed -n '/== INSTALLED/,/== CONFLICTS/p' <<<"$out" | head -n -1)")
[[ $n -eq 5 ]] || { ok=0; FAIL+=("fresh: INSTALLED has $n lines, want 5"); }
grep -q '{{' "$TMP/fresh"/*.md "$TMP/fresh/llms.txt" "$TMP/fresh/VERSION" &&
  { ok=0; FAIL+=("fresh: leftover placeholder"); }
grep -q '{%' "$TMP/fresh"/*.md "$TMP/fresh/llms.txt" &&
  { ok=0; FAIL+=("fresh: leftover conditional"); }
grep -q 'demo' "$TMP/fresh/AGENTS.md" ||
  { ok=0; FAIL+=("fresh: PROJECT_NAME not substituted"); }
[[ -f $TMP/fresh/.manifest/manifest.yaml.checksum ]] ||
  { ok=0; FAIL+=("fresh: checksum missing"); }
((ok)) && PASS+=("fresh")

# Fixture 2: project with AGENTS.md and VERSIONING.md already present.
mkdir -p "$TMP/conflict" && git -C "$TMP/conflict" init -q
printf 'existing agents\n' >"$TMP/conflict/AGENTS.md"
printf 'existing versioning\n' >"$TMP/conflict/VERSIONING.md"
cp "$TMP/conflict/AGENTS.md" "$TMP/agents.before"
cp "$TMP/conflict/VERSIONING.md" "$TMP/versioning.before"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/conflict" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 3 ]] || { ok=0; FAIL+=("conflict: exit $rc != 3"); }
for f in llms.txt COMMIT_RULES.md VERSION; do
  [[ -f $TMP/conflict/$f ]] || { ok=0; FAIL+=("conflict: $f not installed"); }
done
cmp -s "$TMP/agents.before" "$TMP/conflict/AGENTS.md" ||
  { ok=0; FAIL+=("conflict: AGENTS.md modified"); }
cmp -s "$TMP/versioning.before" "$TMP/conflict/VERSIONING.md" ||
  { ok=0; FAIL+=("conflict: VERSIONING.md modified"); }
n=$(sed -n '/== CONFLICTS/,/== SKIPPED/p' <<<"$out" | grep -c '^  ')
[[ $n -eq 2 ]] || { ok=0; FAIL+=("conflict: CONFLICTS has $n lines, want 2"); }
[[ -f $TMP/conflict/RELEASES.md ]] && { ok=0; FAIL+=("conflict: RELEASES.md installed"); }
((ok)) && PASS+=("conflict")

# Fixture 3: tampered manifest.yaml checksum.
mkdir -p "$TMP/tampered" && git -C "$TMP/tampered" init -q
bash "$INIT" --templates "$TEMPLATES" --project "$TMP/tampered" \
  --project-name demo --tracks code >/dev/null 2>&1
cp "$TMP/tampered/.manifest/manifest.yaml" "$TMP/config.before"
cp "$TMP/tampered/.manifest/manifest.yaml.checksum" "$TMP/checksum.before"
printf 'tampered' >>"$TMP/tampered/.manifest/manifest.yaml"
cp "$TMP/tampered/.manifest/manifest.yaml" "$TMP/config.tampered"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/tampered" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("tampered: exit $rc, want non-zero"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("tampered: no CHECKSUM_MISMATCH"); }
cmp -s "$TMP/config.tampered" "$TMP/tampered/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("tampered: config modified"); }
cmp -s "$TMP/checksum.before" "$TMP/tampered/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("tampered: checksum modified"); }
((ok)) && PASS+=("tampered")

# Fixture 4: directory outside a Git work tree.
mkdir -p "$TMP/nogit"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/nogit" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("no-git: exit $rc, want non-zero"); }
grep -q -i 'git' <<<"$out" ||
  { ok=0; FAIL+=("no-git: report does not name the Git check"); }
[[ -e $TMP/nogit/.manifest ]] && { ok=0; FAIL+=("no-git: .manifest created"); }
((ok)) && PASS+=("no-git")

# Fixture 5: partial install followed by an integrity failure
# (bad version.template with an unresolvable placeholder).
mkdir -p "$TMP/corrupt" && git -C "$TMP/corrupt" init -q
mkdir -p "$TMP/badtpl"
cp "$TEMPLATES"/agents.template.md "$TEMPLATES"/llm.template.txt \
  "$TEMPLATES"/commit-rules.template.md \
  "$TEMPLATES"/versioning.template.md "$TMP/badtpl/"
printf '{{UNKNOWN_VAR}}\n' >"$TMP/badtpl/version.template"
out=$(bash "$INIT" --templates "$TMP/badtpl" --project "$TMP/corrupt" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("corrupt: exit $rc, want non-zero"); }
grep -q 'INSTALL_CORRUPT VERSION' <<<"$out" ||
  { ok=0; FAIL+=("corrupt: no INSTALL_CORRUPT VERSION"); }
[[ ! -f $TMP/corrupt/VERSION ]] || { ok=0; FAIL+=("corrupt: VERSION installed"); }
for f in AGENTS.md llms.txt COMMIT_RULES.md VERSIONING.md; do
  [[ ! -f $TMP/corrupt/$f ]] ||
    { ok=0; FAIL+=("corrupt: $f left behind (rollback failed)"); }
done
[[ ! -e $TMP/corrupt/.manifest ]] ||
  { ok=0; FAIL+=("corrupt: .manifest left behind (rollback failed)"); }
grep -q '== REPORT\|== INSTALLED\|== CONFLICTS' <<<"$out" ||
  { ok=0; FAIL+=("corrupt: full report not printed"); }
((ok)) && PASS+=("corrupt")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
