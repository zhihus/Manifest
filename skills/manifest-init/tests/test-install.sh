#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); INIT=$ROOT/scripts/install.sh; TEMPLATES=$ROOT/templates
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT; fails=0
new_repo(){ mkdir -p "$1"; git -C "$1" init -q; }
run(){ bash "$INIT" --project "$1" --templates "$TEMPLATES" --project-name demo --purpose test --tracks code "${@:2}"; }
new_repo "$TMP/fresh"; run "$TMP/fresh" >"$TMP/fresh.out"
for f in .manifest/manifest.yaml .manifest/manifest.yaml.checksum; do [[ -f "$TMP/fresh/$f" ]] || { echo "FAIL fresh missing $f"; fails=$((fails+1)); }; done
grep -A1 '^  todoing:' "$TMP/fresh/.manifest/manifest.yaml" | grep -q 'enabled: true' || { echo "FAIL Todoing default"; fails=$((fails+1)); }
grep -A1 '^  openspec:' "$TMP/fresh/.manifest/manifest.yaml" | grep -q 'enabled: false' || { echo "FAIL OpenSpec default"; fails=$((fails+1)); }
before_rerun=$(sha256sum "$TMP/fresh/.manifest/manifest.yaml" "$TMP/fresh/.manifest/manifest.yaml.checksum")
run "$TMP/fresh" >"$TMP/fresh-rerun.out"
after_rerun=$(sha256sum "$TMP/fresh/.manifest/manifest.yaml" "$TMP/fresh/.manifest/manifest.yaml.checksum")
[[ "$before_rerun" == "$after_rerun" ]] || { echo "FAIL fresh rerun changed config"; fails=$((fails+1)); }
for id in agents llm-navigation versioning releases logging code-rules test-rules commit-rules version llmignore; do
 grep -A2 "^  $id:" "$TMP/fresh/.manifest/manifest.yaml" | grep -q 'enabled: false' || { echo "FAIL context default $id"; fails=$((fails+1)); }
done
for f in AGENTS.md llms.txt VERSIONING.md RELEASES.md LOG_RULES.md CODE_RULES.md TEST_RULES.md COMMIT_RULES.md VERSION .llmignore openspec/config.yaml; do [[ ! -e "$TMP/fresh/$f" ]] || { echo "FAIL unexpected optional file $f"; fails=$((fails+1)); }; done
grep -q '^temp/$' "$TMP/fresh/.gitignore" || { echo "FAIL temp ignore"; fails=$((fails+1)); }
new_repo "$TMP/single"
run "$TMP/single" --context-file agents=enabled >"$TMP/single.out"
[[ -f "$TMP/single/AGENTS.md" ]] || { echo "FAIL selected single file not installed"; fails=$((fails+1)); }
for f in llms.txt VERSIONING.md RELEASES.md LOG_RULES.md CODE_RULES.md TEST_RULES.md COMMIT_RULES.md VERSION .llmignore; do
 [[ ! -e "$TMP/single/$f" ]] || { echo "FAIL unselected file installed: $f"; fails=$((fails+1)); }
done

new_repo "$TMP/partial"; mkdir -p "$TMP/partial/.manifest"; printf 'owned\n' >"$TMP/partial/AGENTS.md"
run "$TMP/partial" --context-file agents=enabled --context-file code-rules=enabled >"$TMP/partial.out"
grep -q '^owned$' "$TMP/partial/AGENTS.md" || { echo "FAIL existing file overwritten"; fails=$((fails+1)); }
[[ -f "$TMP/partial/CODE_RULES.md" ]] || { echo "FAIL selected missing file not added"; fails=$((fails+1)); }
[[ ! -e "$TMP/partial/llms.txt" ]] || { echo "FAIL disabled context file installed"; fails=$((fails+1)); }
cp "$TMP/partial/.manifest/manifest.yaml" "$TMP/config"; cp "$TMP/partial/.manifest/manifest.yaml.checksum" "$TMP/checksum"
run "$TMP/partial" >/dev/null
cmp -s "$TMP/config" "$TMP/partial/.manifest/manifest.yaml" || { echo "FAIL config changed"; fails=$((fails+1)); }
cmp -s "$TMP/checksum" "$TMP/partial/.manifest/manifest.yaml.checksum" || { echo "FAIL checksum changed"; fails=$((fails+1)); }
printf '\n# tamper\n' >>"$TMP/partial/.manifest/manifest.yaml"
if run "$TMP/partial" >"$TMP/tamper.out" 2>&1; then echo "FAIL tamper accepted"; fails=$((fails+1)); else grep -q CHECKSUM_MISMATCH "$TMP/tamper.out" || { echo "FAIL tamper diagnostic"; fails=$((fails+1)); }; fi
new_repo "$TMP/legacy"; mkdir -p "$TMP/legacy/.manifest"; printf 'project_name=old\n' >"$TMP/legacy/.manifest/manifest.yaml"
printf 'sha256sum:%s\n' "$(sha256sum "$TMP/legacy/.manifest/manifest.yaml" | awk '{print $1}')" >"$TMP/legacy/.manifest/manifest.yaml.checksum"
if run "$TMP/legacy" >"$TMP/legacy.out" 2>&1; then echo "FAIL legacy accepted"; fails=$((fails+1)); else grep -q CONFIG_UNSUPPORTED "$TMP/legacy.out" || { echo "FAIL legacy diagnostic"; fails=$((fails+1)); }; fi
new_repo "$TMP/legacy-v1"
mkdir -p "$TMP/legacy-v1/.manifest"
cat >"$TMP/legacy-v1/.manifest/manifest.yaml" <<'YAML'
format_version: 1
project:
  name: legacy-v1
components:
  todoing:
    enabled: true
  openspec:
    enabled: false
checks:
  workflow_preflight:
    enabled: false
  git_hooks:
    enabled: false
  git_checks:
    enabled: false
  openspec_validation:
    enabled: false
  tests:
    enabled: false
  review_gate:
    enabled: false
  additional_gates:
    enabled: false
YAML
printf 'sha256sum:%s\n' "$(sha256sum "$TMP/legacy-v1/.manifest/manifest.yaml" | awk '{print $1}')" >"$TMP/legacy-v1/.manifest/manifest.yaml.checksum"
run "$TMP/legacy-v1" >"$TMP/legacy-v1.out"
[[ ! -e "$TMP/legacy-v1/AGENTS.md" ]] || { echo "FAIL legacy config installed context"; fails=$((fails+1)); }
grep -q 'context_files settings absent' "$TMP/legacy-v1.out" || { echo "FAIL legacy context migration warning"; fails=$((fails+1)); }
if run "$TMP/partial" --context-file version=enabled >"$TMP/override.out" 2>&1; then
 echo "FAIL existing config accepted context override"; fails=$((fails+1))
else
 grep -q EXISTING_CONFIG_IMMUTABLE "$TMP/override.out" || { echo "FAIL existing config override diagnostic"; fails=$((fails+1)); }
if run "$TMP/partial" --todoing disabled >"$TMP/component-override.out" 2>&1; then
 echo "FAIL existing config accepted component override"; fails=$((fails+1))
else
 grep -q EXISTING_CONFIG_IMMUTABLE "$TMP/component-override.out" || { echo "FAIL component override diagnostic"; fails=$((fails+1)); }
fi
fi

echo "Regression failures: $fails"
((fails == 0))
