#!/usr/bin/env bash
# test-manifest-init.sh — mechanical verification of manifest-init.sh
# against the five fixture scenarios of add-manifest-init-mvp (FR 4.1)
# plus four regression tests (reinit, probe, usage, interview EOF).
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

hash_pair() { # hash_pair <manifest-dir> — portable snapshot for the re-init fixture
  local dir=$1
  if (cd "$dir" && sha256sum manifest.yaml manifest.yaml.checksum >/dev/null 2>&1); then
    (cd "$dir" && sha256sum manifest.yaml manifest.yaml.checksum)
  elif (cd "$dir" && shasum -a 256 manifest.yaml manifest.yaml.checksum >/dev/null 2>&1); then
    (cd "$dir" && shasum -a 256 manifest.yaml manifest.yaml.checksum)
  else
    return 1
  fi
}

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
n=$(grep -c '^  ' <<<"$(sed -n '/== INSTALLED/,/== CONFLICTS/p' <<<"$out" | sed '$d')")
[[ $n -eq 5 ]] || { ok=0; FAIL+=("fresh: INSTALLED has $n lines, want 5"); }
grep -q '{{' "$TMP/fresh"/*.md "$TMP/fresh/llms.txt" "$TMP/fresh/VERSION" &&
  { ok=0; FAIL+=("fresh: leftover placeholder"); }
grep -q '{%' "$TMP/fresh"/*.md "$TMP/fresh/llms.txt" &&
  { ok=0; FAIL+=("fresh: leftover conditional"); }
grep -q 'demo' "$TMP/fresh/AGENTS.md" ||
  { ok=0; FAIL+=("fresh: PROJECT_NAME not substituted"); }
[[ -f $TMP/fresh/.manifest/manifest.yaml.checksum ]] ||
  { ok=0; FAIL+=("fresh: checksum missing"); }
for expected in
  '^format_version: 1$'
  '^  name: "demo"$'
  '^  tracks: code$'
  '^components:$'
  '^  todoing:$'
  '^    enabled: true$'
  '^  openspec:$'
  '^checks:$'
  '^  workflow_preflight:$'
  '^  git_hooks:$'
  '^  git_checks:$'
  '^  openspec_validation:$'
  '^  tests:$'
  '^  review_gate:$'
  '^  additional_gates:$'
do
  grep -q "$expected" "$TMP/fresh/.manifest/manifest.yaml" ||
    { ok=0; FAIL+=("fresh: config missing '$expected'"); }
done
[[ $(grep -c '^    enabled: true
! grep -q '^project_name=' "$TMP/fresh/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("fresh: legacy key=value format remains"); }
((ok)) && PASS+=("fresh")

# Regression: project names containing quotes and backslashes remain valid YAML scalars.
mkdir -p "$TMP/yaml-name" && git -C "$TMP/yaml-name" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/yaml-name" \
  --project-name 'demo "quoted" \path' --tracks mixed 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("yaml-name: exit $rc != 0"); }
grep -Fq '  name: "demo \"quoted\" \\path"' "$TMP/yaml-name/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("yaml-name: project name is not escaped as a YAML scalar"); }
((ok)) && PASS+=("yaml-name")

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  name: "demo"

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  tracks: code

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^components:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  todoing:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^    enabled: true

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  openspec:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^checks:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  workflow_preflight:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  git_hooks:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  git_checks:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  openspec_validation:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  tests:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  review_gate:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  additional_gates:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
; do
  grep -q "$expected" "$TMP/fresh/.manifest/manifest.yaml" ||
    { ok=0; FAIL+=("fresh: config missing '$expected'"); }
done
[[ $(grep -c '^    enabled: false

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 "$TMP/fresh/.manifest/manifest.yaml") -eq 7 ]] ||
  { ok=0; FAIL+=("fresh: expected seven disabled optional controls"); }
! grep -q '^project_name=' "$TMP/fresh/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("fresh: legacy key=value format remains"); }
((ok)) && PASS+=("fresh")

# Regression: project names containing YAML quotes and backslashes are escaped.
mkdir -p "$TMP/quoted" && git -C "$TMP/quoted" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/quoted" \
  --project-name 'demo "quoted" \\path' --tracks mixed 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("yaml-escaping: exit $rc != 0"); }
grep -Fq '  name: "demo \\"quoted\\" \\\\path"' "$TMP/quoted/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("yaml-escaping: project name is not escaped as a YAML scalar"); }
((ok)) && PASS+=("yaml-escaping")

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 "$TMP/fresh/.manifest/manifest.yaml") -eq 2 ]] ||
  { ok=0; FAIL+=("fresh: expected Todoing and OpenSpec enabled"); }
[[ $(grep -c '^    enabled: false
! grep -q '^project_name=' "$TMP/fresh/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("fresh: legacy key=value format remains"); }
((ok)) && PASS+=("fresh")

# Regression: project names containing quotes and backslashes remain valid YAML scalars.
mkdir -p "$TMP/yaml-name" && git -C "$TMP/yaml-name" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/yaml-name" \
  --project-name 'demo "quoted" \path' --tracks mixed 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("yaml-name: exit $rc != 0"); }
grep -Fq '  name: "demo \"quoted\" \\path"' "$TMP/yaml-name/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("yaml-name: project name is not escaped as a YAML scalar"); }
((ok)) && PASS+=("yaml-name")

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  name: "demo"

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  tracks: code

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^components:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  todoing:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^    enabled: true

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  openspec:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^checks:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  workflow_preflight:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  git_hooks:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  git_checks:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  openspec_validation:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  tests:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  review_gate:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  additional_gates:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
; do
  grep -q "$expected" "$TMP/fresh/.manifest/manifest.yaml" ||
    { ok=0; FAIL+=("fresh: config missing '$expected'"); }
done
[[ $(grep -c '^    enabled: false

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 "$TMP/fresh/.manifest/manifest.yaml") -eq 7 ]] ||
  { ok=0; FAIL+=("fresh: expected seven disabled optional controls"); }
! grep -q '^project_name=' "$TMP/fresh/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("fresh: legacy key=value format remains"); }
((ok)) && PASS+=("fresh")

# Regression: project names containing YAML quotes and backslashes are escaped.
mkdir -p "$TMP/quoted" && git -C "$TMP/quoted" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/quoted" \
  --project-name 'demo "quoted" \\path' --tracks mixed 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("yaml-escaping: exit $rc != 0"); }
grep -Fq '  name: "demo \\"quoted\\" \\\\path"' "$TMP/quoted/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("yaml-escaping: project name is not escaped as a YAML scalar"); }
((ok)) && PASS+=("yaml-escaping")

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 "$TMP/fresh/.manifest/manifest.yaml") -eq 7 ]] ||
  { ok=0; FAIL+=("fresh: expected seven disabled optional controls"); }
grep -Eq '^  created: "[0-9]{4}-[0-9]{2}-[0-9]{2}"
! grep -q '^project_name=' "$TMP/fresh/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("fresh: legacy key=value format remains"); }
((ok)) && PASS+=("fresh")

# Regression: project names containing quotes and backslashes remain valid YAML scalars.
mkdir -p "$TMP/yaml-name" && git -C "$TMP/yaml-name" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/yaml-name" \
  --project-name 'demo "quoted" \path' --tracks mixed 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("yaml-name: exit $rc != 0"); }
grep -Fq '  name: "demo \"quoted\" \\path"' "$TMP/yaml-name/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("yaml-name: project name is not escaped as a YAML scalar"); }
((ok)) && PASS+=("yaml-name")

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  name: "demo"

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  tracks: code

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^components:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  todoing:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^    enabled: true

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  openspec:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^checks:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  workflow_preflight:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  git_hooks:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  git_checks:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  openspec_validation:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  tests:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  review_gate:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  additional_gates:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
; do
  grep -q "$expected" "$TMP/fresh/.manifest/manifest.yaml" ||
    { ok=0; FAIL+=("fresh: config missing '$expected'"); }
done
[[ $(grep -c '^    enabled: false

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 "$TMP/fresh/.manifest/manifest.yaml") -eq 7 ]] ||
  { ok=0; FAIL+=("fresh: expected seven disabled optional controls"); }
! grep -q '^project_name=' "$TMP/fresh/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("fresh: legacy key=value format remains"); }
((ok)) && PASS+=("fresh")

# Regression: project names containing YAML quotes and backslashes are escaped.
mkdir -p "$TMP/quoted" && git -C "$TMP/quoted" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/quoted" \
  --project-name 'demo "quoted" \\path' --tracks mixed 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("yaml-escaping: exit $rc != 0"); }
grep -Fq '  name: "demo \\"quoted\\" \\\\path"' "$TMP/quoted/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("yaml-escaping: project name is not escaped as a YAML scalar"); }
((ok)) && PASS+=("yaml-escaping")

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 "$TMP/fresh/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("fresh: created date missing or invalid"); }
! grep -q '^project_name=' "$TMP/fresh/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("fresh: legacy key=value format remains"); }
((ok)) && PASS+=("fresh")

# Regression: project names containing quotes and backslashes remain valid YAML scalars.
mkdir -p "$TMP/yaml-name" && git -C "$TMP/yaml-name" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/yaml-name" \
  --project-name 'demo "quoted" \path' --tracks mixed 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("yaml-name: exit $rc != 0"); }
grep -Fq '  name: "demo \"quoted\" \\path"' "$TMP/yaml-name/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("yaml-name: project name is not escaped as a YAML scalar"); }
((ok)) && PASS+=("yaml-name")

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  name: "demo"

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  tracks: code

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^components:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  todoing:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^    enabled: true

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  openspec:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^checks:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  workflow_preflight:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  git_hooks:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  git_checks:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  openspec_validation:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  tests:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  review_gate:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 \
  '^  additional_gates:

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
; do
  grep -q "$expected" "$TMP/fresh/.manifest/manifest.yaml" ||
    { ok=0; FAIL+=("fresh: config missing '$expected'"); }
done
[[ $(grep -c '^    enabled: false

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
 "$TMP/fresh/.manifest/manifest.yaml") -eq 7 ]] ||
  { ok=0; FAIL+=("fresh: expected seven disabled optional controls"); }
! grep -q '^project_name=' "$TMP/fresh/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("fresh: legacy key=value format remains"); }
((ok)) && PASS+=("fresh")

# Regression: project names containing YAML quotes and backslashes are escaped.
mkdir -p "$TMP/quoted" && git -C "$TMP/quoted" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/quoted" \
  --project-name 'demo "quoted" \\path' --tracks mixed 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("yaml-escaping: exit $rc != 0"); }
grep -Fq '  name: "demo \\"quoted\\" \\\\path"' "$TMP/quoted/.manifest/manifest.yaml" ||
  { ok=0; FAIL+=("yaml-escaping: project name is not escaped as a YAML scalar"); }
((ok)) && PASS+=("yaml-escaping")

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

# Regression: re-init refuses with the REINIT_REFUSED token.
# Snapshot the files BEFORE the refused attempt.
ok=1
bef=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility"); }
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/fresh" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("reinit: exit $rc, want non-zero"); }
grep -q 'REINIT_REFUSED' <<<"$out" ||
  { ok=0; FAIL+=("reinit: no REINIT_REFUSED token"); }
# .manifest contents must stay byte-identical across the refused run.
aft=$(hash_pair "$TMP/fresh/.manifest") || { ok=0; FAIL+=("reinit: no working SHA-256 utility on second read"); }
[[ $bef == "$aft" ]] || { ok=0; FAIL+=("reinit: .manifest files modified"); }
((ok)) && PASS+=("reinit")

# Regression: a pre-existing user file named .manifest-write-probe
# survives init untouched; no probe leftovers remain.
mkdir -p "$TMP/probe" && git -C "$TMP/probe" init -q
printf 'user data\n' >"$TMP/probe/.manifest-write-probe"
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/probe" \
  --project-name demo --tracks code 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("probe: exit $rc, want 0"); }
[[ "$(cat "$TMP/probe/.manifest-write-probe" 2>/dev/null)" == 'user data' ]] ||
  { ok=0; FAIL+=("probe: user file modified or removed"); }
ls "$TMP/probe"/.manifest-write-probe.* >/dev/null 2>&1 &&
  { ok=0; FAIL+=("probe: leftover probe file"); }
((ok)) && PASS+=("probe")

# Regression: --templates without a value prints usage, exits 2.
out=$(bash "$INIT" --templates 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -eq 2 ]] || { ok=0; FAIL+=("usage: exit $rc, want 2"); }
grep -q 'usage:' <<<"$out" || { ok=0; FAIL+=("usage: no usage line"); }
((ok)) && PASS+=("usage")

# Regression: interview EOF (empty stdin, no flags) fails cleanly,
# nothing is written to the project.
mkdir -p "$TMP/eof" && git -C "$TMP/eof" init -q
out=$(bash "$INIT" --templates "$TEMPLATES" --project "$TMP/eof" \
  </dev/null 2>&1) && rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("eof: exit $rc, want non-zero"); }
grep -q 'INTERVIEW_EOF' <<<"$out" ||
  { ok=0; FAIL+=("eof: no INTERVIEW_EOF message"); }
[[ ! -e $TMP/eof/.manifest ]] ||
  { ok=0; FAIL+=("eof: partial .manifest left behind"); }
((ok)) && PASS+=("eof")

# Regression: SHA-256 detection skips a broken sha256sum and falls
# back to shasum (macOS scenario). stubbin shadows the real
# sha256sum with a failing stub; the rest of PATH stays intact.
mkdir -p "$TMP/shasum" "$TMP/stubbin" && git -C "$TMP/shasum" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/stubbin/sha256sum"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -eq 0 ]] || { ok=0; FAIL+=("shasum: exit $rc, want 0: $out"); }
grep -qE '^[a-z]+:[0-9a-f]{64}' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum not <tool>:<sha256-hex>"); }
grep -q '^shasum:' "$TMP/shasum/.manifest/manifest.yaml.checksum" ||
  { ok=0; FAIL+=("shasum: checksum does not record the shasum tool"); }
# Tamper check with the same environment: guard must still work.
printf 'x' >>"$TMP/shasum/.manifest/manifest.yaml"
out=$(PATH="$TMP/stubbin:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/shasum" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("shasum: tamper not detected"); }
grep -q 'CHECKSUM_MISMATCH' <<<"$out" ||
  { ok=0; FAIL+=("shasum: no CHECKSUM_MISMATCH"); }
((ok)) && PASS+=("shasum")

# A present but non-working Perl executable must fail preflight.
mkdir -p "$TMP/no-perl" "$TMP/perl-stub"
git -C "$TMP/no-perl" init -q
printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/perl-stub/perl"
chmod +x "$TMP/perl-stub/perl"
out=$(PATH="$TMP/perl-stub:$PATH" bash "$INIT" --templates "$TEMPLATES" \
  --project "$TMP/no-perl" --project-name demo --tracks code 2>&1) &&
  rc=0 || rc=$?
ok=1
[[ $rc -ne 0 ]] || { ok=0; FAIL+=("perl-preflight: exit $rc, want non-zero"); }
grep -q 'Perl is required' <<<"$out" ||
  { ok=0; FAIL+=("perl-preflight: missing actionable Perl message"); }
[[ ! -e $TMP/no-perl/.manifest ]] ||
  { ok=0; FAIL+=("perl-preflight: .manifest created despite missing Perl"); }
((ok)) && PASS+=("perl-preflight")

echo "== RESULTS (${#PASS[@]} passed, ${#FAIL[@]} failed)"
printf 'PASS %s\n' "${PASS[@]}"
if ((${#FAIL[@]})); then printf 'FAIL %s\n' "${FAIL[@]}"; fi
((${#FAIL[@]})) && exit 1
exit 0
