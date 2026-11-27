#!/usr/bin/env bash
set -euo pipefail
PROJECT=.
TEMPLATES="$(cd "$(dirname "$0")/.." && pwd)/templates"
PROJECT_NAME= PURPOSE= TRACKS= INITIAL_VERSION=0.1.0
usage(){ echo "usage: install.sh [--project DIR] [--templates DIR] [--project-name NAME] [--purpose TEXT] [--tracks none|code|documentation|mixed]"; exit 2; }
while (($#)); do
 case "$1" in
  --project|--templates|--project-name|--purpose|--tracks|--initial-version)
   (($# >= 2)) || usage
   case "$1" in
    --project) PROJECT=$2;; --templates) TEMPLATES=$2;; --project-name) PROJECT_NAME=$2;;
    --purpose) PURPOSE=$2;; --tracks) TRACKS=$2;; --initial-version) INITIAL_VERSION=$2;;
   esac; shift 2;;
  *) usage;;
 esac
done
[[ -d $PROJECT ]] || { echo "PROJECT_NOT_FOUND: $PROJECT"; exit 1; }
PROJECT=$(cd "$PROJECT" && pwd); MK=$PROJECT/.manifest
INSTALLED=(); SKIPPED=(); PENDING=()
sha256_of(){ if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'; else return 1; fi; }
fail(){ echo "$1" >&2; exit 1; }
analyze_tracks(){
 local code=0 docs=0
 find "$PROJECT" -path "$PROJECT/.git" -prune -o -path "$PROJECT/.manifest" -prune -o -type f \( -name '*.c' -o -name '*.cpp' -o -name '*.cs' -o -name '*.go' -o -name '*.java' -o -name '*.js' -o -name '*.py' -o -name '*.rs' -o -name '*.sh' -o -name '*.ts' \) -print | grep -q . && code=1 || true
 [[ -d "$PROJECT/docs" ]] && docs=1
 if ((code && docs)); then echo mixed; elif ((code)); then echo code; elif ((docs)); then echo documentation; else echo none; fi
}
[[ -n $TRACKS ]] || TRACKS=$(analyze_tracks)
case "$TRACKS" in none|code|documentation|mixed) ;; *) fail "INVALID_TRACKS: $TRACKS";; esac
[[ -n $PROJECT_NAME ]] || PROJECT_NAME=$(basename "$PROJECT")
[[ -n $PURPOSE ]] || PURPOSE="Not established."
[[ $PROJECT_NAME != *$'\n'* && $PROJECT_NAME != *$'\r'* ]] || fail INVALID_PROJECT_NAME
[[ -d $TEMPLATES && -r $TEMPLATES ]] || fail "TEMPLATES_UNAVAILABLE: $TEMPLATES"
command -v git >/dev/null 2>&1 || fail GIT_UNAVAILABLE
git -C "$PROJECT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail NOT_A_GIT_WORKTREE
command -v perl >/dev/null 2>&1 && perl -e 'exit 0' >/dev/null 2>&1 || fail PERL_REQUIRED
sha256_of "$0" >/dev/null || fail SHA256_REQUIRED
probe=$(mktemp "$PROJECT/.manifest-write-probe.XXXXXX") || fail PROJECT_NOT_WRITABLE
rm -f "$probe"
CONFIG=$MK/manifest.yaml; CHECKSUM=$MK/manifest.yaml.checksum; config_exists=0
if [[ -e $CONFIG ]]; then
 config_exists=1
 [[ -f $CHECKSUM ]] || fail "CHECKSUM_MISSING: refusing writes"
 expected=$(sed 's/^[^:]*://' "$CHECKSUM"); actual=$(sha256_of "$CONFIG")
 [[ $actual == "$expected" ]] || fail "CHECKSUM_MISMATCH: $CONFIG"
 grep -q '^format_version: 1$' "$CONFIG" || fail "CONFIG_UNSUPPORTED: explicit migration required"
 for key in todoing openspec; do grep -A1 "^  $key:" "$CONFIG" | grep -Eq '^[[:space:]]+enabled: (true|false)$' || fail "CONFIG_INVALID: components.$key.enabled"; done
 for key in workflow_preflight git_hooks git_checks openspec_validation tests review_gate additional_gates; do grep -A1 "^  $key:" "$CONFIG" | grep -Eq '^[[:space:]]+enabled: (true|false)$' || fail "CONFIG_INVALID: checks.$key.enabled"; done
elif [[ -e $CHECKSUM ]]; then fail CHECKSUM_ORPHANED
fi
if (( ! config_exists )); then
 if [[ -t 0 ]]; then
  read -r -p "Project name [$PROJECT_NAME]: " answer; [[ -z $answer ]] || PROJECT_NAME=$answer
  read -r -p "Project purpose [$PURPOSE]: " answer; [[ -z $answer ]] || PURPOSE=$answer
  read -r -p "Tracks [$TRACKS]: " answer; [[ -z $answer ]] || TRACKS=$answer
  case "$TRACKS" in none|code|documentation|mixed) ;; *) fail "INVALID_TRACKS: $TRACKS";; esac
 fi
 mkdir -p "$MK"
 yaml_name=$(printf '%s' "$PROJECT_NAME" | perl -pe 's/\\/\\\\/g; s/"/\\"/g; s/\r/\\r/g')
 tmp=$(mktemp "$MK/.manifest.yaml.XXXXXX")
 {
  printf 'format_version: 1\nproject:\n  name: "%s"\n  tracks: %s\n  created: "%s"\n' "$yaml_name" "$TRACKS" "$(date +%F)"
  printf 'components:\n  todoing:\n    enabled: true\n  openspec:\n    enabled: true\nchecks:\n'
  for key in workflow_preflight git_hooks git_checks openspec_validation tests review_gate additional_gates; do printf '  %s:\n    enabled: false\n' "$key"; done
 } >"$tmp"
 ln "$tmp" "$CONFIG" 2>/dev/null || { rm -f "$tmp"; fail CONFIG_RACE; }; rm -f "$tmp"
 hash=$(sha256_of "$CONFIG"); tmp=$(mktemp "$MK/.checksum.XXXXXX"); printf 'sha256sum:%s\n' "$hash" >"$tmp"
 ln "$tmp" "$CHECKSUM" 2>/dev/null || { rm -f "$tmp"; fail CHECKSUM_RACE; }; rm -f "$tmp"
 INSTALLED+=(".manifest/manifest.yaml" ".manifest/manifest.yaml.checksum")
else SKIPPED+=(".manifest/manifest.yaml (preserved; checksum valid)")
fi
NAMES=(AGENTS.md llms.txt VERSIONING.md RELEASES.md LOG_RULES.md CODE_RULES.md TEST_RULES.md COMMIT_RULES.md VERSION .llmignore)
SOURCES=(agents.template.md llm.template.txt versioning.template.md code-releases.template.md code-log-rules.template.md code-rules.template.md code-test-rules.template.md commit-rules.template.md version.template llmignore.template)
tmpdir=$(mktemp -d); trap 'rm -rf "$tmpdir"' EXIT
for i in "\${!NAMES[@]}"; do
 name=\${NAMES[$i]}; src=$TEMPLATES/\${SOURCES[$i]}
 [[ -f $src ]] || fail "TEMPLATE_MISSING: $src"
 if [[ -e $PROJECT/$name ]]; then SKIPPED+=("$name (already exists; preserved)"); continue; fi
 rendered=$tmpdir/$name
 PROJECT_NAME="$PROJECT_NAME" PURPOSE="$PURPOSE" INITIAL_VERSION="$INITIAL_VERSION" perl -pe '
  s/\{%\s*if\s+\w+\s*%\}(.*?)\{%\s*else\s*%\}(.*?)\{%\s*endif\s*%\}/$2/gs;
  s/\{%\s*if\s+\w+\s*%\}.*?\{%\s*endif\s*%\}//gs;
  s/\{\{PROJECT_NAME\}\}/$ENV{PROJECT_NAME}/g;
  s/\{\{PROJECT_PURPOSE\}\}/$ENV{PURPOSE}/g;
  s/\{\{INITIAL_VERSION\}\}/$ENV{INITIAL_VERSION}/g;
  s/\{\{[A-Z0-9_]+\}\}//g;
 ' "$src" >"$rendered"
 grep -q -e '{{' -e '{%' "$rendered" && fail "TEMPLATE_RENDER_FAILED: $name"
 if ln "$rendered" "$PROJECT/$name" 2>/dev/null; then INSTALLED+=("$name"); else SKIPPED+=("$name (appeared during install; preserved)"); fi
done
if [[ -f $PROJECT/.gitignore ]]; then
 if ! grep -Eq '^[[:space:]]*temp/([[:space:]]|$)' "$PROJECT/.gitignore"; then printf '\n# Manifest temporary workspace\ntemp/\n' >>"$PROJECT/.gitignore"; INSTALLED+=(".gitignore (added temp/ exclusion)"); else SKIPPED+=(".gitignore temp/ exclusion already present"); fi
else printf '# Manifest temporary workspace\ntemp/\n' >"$PROJECT/.gitignore"; INSTALLED+=(".gitignore"); fi
if grep -A1 '^  openspec:' "$CONFIG" | grep -q 'enabled: true'; then
 mkdir -p "$PROJECT/openspec/specs" "$PROJECT/openspec/changes"
 if [[ ! -e $PROJECT/openspec/config.yaml ]]; then
  [[ -f $TEMPLATES/openspec-config.yaml ]] || fail OPENSPEC_TEMPLATE_MISSING
  if ln "$TEMPLATES/openspec-config.yaml" "$PROJECT/openspec/config.yaml" 2>/dev/null; then INSTALLED+=("openspec/config.yaml"); else SKIPPED+=("openspec/config.yaml (preserved)"); fi
 else SKIPPED+=("openspec/config.yaml (already exists; preserved)"); fi
fi
if grep -A1 '^  todoing:' "$CONFIG" | grep -q 'enabled: true'; then
 if command -v todoing >/dev/null 2>&1; then PENDING+=("Todoing binary detected; run documented non-destructive store bootstrap")
 else PENDING+=("Todoing enabled; user must install its binary before Todoing workflow use"); fi
fi
echo "== MANIFEST CONNECTION REPORT =="
echo "== INSTALLED (\${#INSTALLED[@]})"; printf '  %s\n' "\${INSTALLED[@]}"
echo "== PRESERVED (\${#SKIPPED[@]})"; printf '  %s\n' "\${SKIPPED[@]}"
echo "== PENDING (\${#PENDING[@]})"; printf '  %s\n' "\${PENDING[@]}"
echo "INIT OK"
