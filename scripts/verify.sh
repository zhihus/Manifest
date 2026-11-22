#!/usr/bin/env bash
# Manifest framework — verify script.
# DEVELOPMENT INFRASTRUCTURE OF THE MANIFEST PROJECT ITSELF.
# NOT part of the framework distribution: do NOT ship this file (or
# scripts/hooks/) in manifest-init dist/ — connected projects get
# their own verification setup.
# Keeps the structure parser in sync with the structure rules source.
# The parser is a derivative of the rules file: it changes only when
# the source changes (a parser bug fix is allowed, but must pass the
# same tests). Baseline for "changed" is HEAD.
#
# Usage: verify.sh            (no arguments)
# Exit codes: 0 OK, 1 FAIL.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
RULES="workflow/file-structure-rules.ru.md"
PARSER="scripts/structure-parser.sh"
declare -a FAILS=()

fail() { FAILS+=("verify.sh: FAIL: $1"); }

# --- 1. existence: rules file and parser at their paths ---
check_existence() {
  [[ -f "$ROOT/$RULES" ]] || fail "файл правил отсутствует / rules file missing: $RULES"
  [[ -f "$ROOT/$PARSER" ]] || fail "парсер отсутствует / parser missing: $PARSER"
}

# --- 2. changed-set analysis: four branches against HEAD ---
# returns: "none" | "parser" | "rules" | "both"
changed_set() {
  local rules_changed=0 parser_changed=0
  git -C "$ROOT" diff HEAD --name-only -- "$RULES" | grep -q . && rules_changed=1
  git -C "$ROOT" diff HEAD --name-only -- "$PARSER" | grep -q . && parser_changed=1
  if (( rules_changed && parser_changed )); then echo "both"
  elif (( rules_changed )); then echo "rules"
  elif (( parser_changed )); then echo "parser"
  else echo "none"; fi
}

# --- 3. parser tests: references (over-reporting) + fixture (under-reporting) ---
run_parser_tests() {
  local f rc=0
  # tmp must survive until the EXIT trap fires, so a script-global
  # variable is used; a function-local one is out of scope by then.
  # A unique per-run temp directory avoids collisions between
  # concurrent invocations and other users of /tmp.
  VERIFY_TMP=$(mktemp -d)
  trap 'rm -rf "$VERIFY_TMP"' EXIT
  for f in "$ROOT"/workflow/*.ru.md "$ROOT"/workflow/*.en.md; do
    if ! bash "$ROOT/$PARSER" "$f" > "$VERIFY_TMP/ref-out.txt" 2>&1; then
      rc=1
      fail "парсер не проходит эталон / parser fails on reference: $f"
      awk 'NR<=10 {print "  " $0}' "$VERIFY_TMP/ref-out.txt"
    fi
  done
  # Fixture written in portable Bash/awk (no Python): byte-identical
  # to the original generator output.
  {
    awk 'BEGIN { s = "# T"; for (i = 0; i < 140; i++) s = s "e"; print s }'
    printf '\n'
    printf '# Метаданные\n'
    printf '> **Status: in-development**  \n'
    printf '> **Type: document**  \n'
    printf '> **Version: 1.0**  \n'
    printf '> **Updated: 2026-11-09**  \n'
    printf '\n'
    printf '# Описание\n'
    printf 'Text.\n'
    printf '\n'
    printf '## 1. Первый\n'
    printf '\n'
    printf '## 3. Второй\n'
    printf '\n'
    printf '### 3.1. Неправильные\n'
    printf '\n'
    printf '❌ пример без метки\n'
  } > "$VERIFY_TMP/fixture.md"
  if bash "$ROOT/$PARSER" "$VERIFY_TMP/fixture.md" > /dev/null 2>&1; then
    rc=1
    fail "парсер не нашёл заложенные нарушения / parser missed the seeded violations"
  fi
  return $rc
}

# --- autonomy checks (portability-principles) ---
# Mechanical privacy/autonomy checks over Manifest's own public
# files. They never modify files and never impose requirements on
# projects that use Manifest.
# Public-file scope (closed list + distributed dirs; local config is
# excluded). workflow/ is not scanned wholesale; any file added to
# manifest-init's install source list is included automatically.
autonomy_scope() {
  local f rel source candidate source_file="$ROOT/scripts/manifest-init.sh"
  for f in AGENTS.md llms.txt docs/manifest.md docs/manifest.compact.md \
           docs/project-manifest.md VERSION VERSIONING.md commit-rules.md \
           releases.md RELEASES.md openspec-rules.md; do
    [[ -f $ROOT/$f ]] || continue
    git -C "$ROOT" ls-files --error-unmatch "$f" >/dev/null 2>&1 &&
      printf '%s\n' "$ROOT/$f"
  done
  # Current checked collections; workflow/ is not scanned wholesale.
  for f in "$ROOT/docs/templates" "$ROOT/openspec/specs"; do
    [[ -d $f ]] || continue
    find "$f" -type f \( -name '*.md' -o -name '*.txt' \) 2>/dev/null
  done | while IFS= read -r f; do
    rel=${f#"$ROOT"/}
    git -C "$ROOT" ls-files --error-unmatch "$rel" >/dev/null 2>&1 &&
      printf '%s\n' "$f"
  done
  # Follow manifest-init's source list: future distributed workflow
  # files enter scope automatically when added to the install list.
  if [[ -f $source_file ]]; then
    while IFS= read -r source; do
      [[ -n $source ]] || continue
      case $source in */*) candidate="$ROOT/$source" ;; *) candidate="$ROOT/docs/templates/$source" ;; esac
      [[ -f $candidate ]] || continue
      rel=${candidate#"$ROOT"/}
      git -C "$ROOT" ls-files --error-unmatch "$rel" >/dev/null 2>&1 &&
        printf '%s\n' "$candidate"
    done < <(
      sed -n '/^BASE_SOURCES=(/,/)/p' "$source_file" |
        sed 's/^BASE_SOURCES=//' | tr -d '()"' | tr ' ' '\n' |
        sed '/^$/d'
    )
  fi
}

# check_autonomy [scope-dir-override] [scripts-dir-override]
#   (overrides exist for fixture testing; empty = real repo scope)
check_autonomy() {
  local scope_dir=${1:-} scripts_dir=${2:-$ROOT/scripts}
  local files=() f bad
  # A line containing this marker is exempt from the checks.
  local allow='portability-allow'
  # Forbidden patterns: machine paths, personal data, unrelated
  # projects. Applied to the whole scope.
  local re_machine='([C-Z]):[\\/]'
  local re_home='(/home/)|(/Users/)'
  local re_local='WorkProjects'
  local re_foreign='(InvestPlan)|(handy[-/ ])|(dictation)'
  local re_email='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
  # Model/harness names apply to every file in the checked scope.
  local re_model='(Qwen)|(ZCode)|(GLM-[0-9])'
  if [[ -n $scope_dir ]]; then
    while IFS= read -r f; do files+=("$f"); done < <(find "$scope_dir" -type f)
  else
    while IFS= read -r f; do files+=("$f"); done < <(autonomy_scope)
  fi
  for f in "${files[@]}"; do
    bad=$(grep -n -v "$allow" "$f" 2>/dev/null | grep -iE "$re_machine|$re_home|$re_local|$re_foreign|$re_email" || true)
    if [[ -n $bad ]]; then
      fail "autonomy: forbidden content (path/PI/foreign project) in: $f
$bad"
    fi
    bad=$(grep -n -v "$allow" "$f" 2>/dev/null | grep -iE "$re_model" || true)
    if [[ -n $bad ]]; then
      fail "autonomy: model/harness-specific content in: $f
$bad"
    fi
  done
  # Bilingual pairing: every English edition in the scope must have a
  # Russian sibling (RU is authoritative).
  for f in "${files[@]}"; do
    case $f in
      *.en.md)
        [[ -f ${f%.en.md}.ru.md ]] ||
          fail "autonomy: English edition without Russian sibling: $f"
        ;;
    esac
  done
  # Declared-dependency check: every external binary invoked by a
  # script must appear in the external dependency register.
  local reg=$ROOT/docs/architecture/external-dependencies.ru.md
  local declared tools t tok f2
  if [[ -f $reg ]]; then
    declared=$(grep '^|' "$reg" | awk -F'|' 'NR>2 {print $2}' |
      grep -oE '[a-z0-9_-]+' |
      tr 'A-Z' 'a-z' | sort -u | tr '\n' ' ')
    declared="$declared bash sh env "
  else
    fail "autonomy: external dependency register missing: docs/architecture/external-dependencies.ru.md"
    declared=" bash sh env "
  fi
  # Include *.sh scripts and the extensionless pre-commit hook.
  local -a script_files=()
  for f2 in "$scripts_dir"/*.sh "$scripts_dir"/hooks/pre-commit; do
    [[ -f $f2 ]] && script_files+=("$f2")
  done
  local funcs keywords
  if (("${#script_files[@]}")); then
    funcs=$(grep -hE '^[a-z_][a-z0-9_]*\(\)' "${script_files[@]}" 2>/dev/null |
      sed 's/()//' | sort -u | tr '\n' ' ')
  else
    funcs=""
  fi
  keywords=" echo printf read local declare exit return if then elif else fi for while until do done case esac function set shift trap cd pwd source eval exec export unset readonly test time wait true false break continue getopts shopt type typeset umask alias bg fg jobs builtin command enable dirs select coproc in { } [ ] [[ ]] "
  # Split compound commands at shell operators and inspect command positions.
  # Human review remains mandatory for constructs outside this conservative scan.
  local f2 line segment t idx
  local -a words=()
  for f2 in "${script_files[@]}"; do
    while IFS= read -r line || [[ -n $line ]]; do
      line=$(printf '%s\n' "$line" |
        sed -e 's/#.*$//' -e 's/"[^"]*"//g' -e "s/'[^']*'//g")
      line=${line//&&/$'\n'}
      line=${line//||/$'\n'}
      line=${line//;/ $'\n'}
      line=${line//|/$'\n'}
      line=${line//&/$'\n'}
      line=${line//(/$'\n'}
      line=${line//)/$'\n'}
      while IFS= read -r segment; do
        read -r -a words <<< "$segment"
        idx=0; t=""
        while (( idx < ${#words[@]} )); do
          t=${words[idx]}
          case $t in
            if|then|elif|else|while|until|do|!|time|coproc|in)
              ((idx+=1)); continue ;;
            command|builtin|exec)
              ((idx+=1))
              if (( idx < ${#words[@]} )) &&
                 [[ ${words[idx]} == -v || ${words[idx]} == -V || ${words[idx]} == -p ]]; then
                idx=${#words[@]}
              fi
              continue ;;
            *=*|\>*|\<*|'$'|'[['|']]'|'(('|'))'|'{'|'}'|'')
              ((idx+=1)); continue ;;
            -*)
              ((idx+=1)); continue ;;
          esac
          break
        done
        [[ -n $t ]] || continue
        case $t in *.sh|[A-Z]*) continue ;; esac
        [[ $keywords == *" $t "* ]] && continue
        [[ $funcs == *" $t "* ]] && continue
        [[ $declared == *" $t "* ]] && continue
        command -v "$t" >/dev/null 2>&1 || continue
        fail "autonomy: undeclared external binary '$t' invoked in $f2 (add it to docs/architecture/external-dependencies.ru.md or remove the use)"
      done <<< "$line"
    done < "$f2"
  done
}

# --- 4. main: branches per the agreed model ---
main() {
  check_existence
  check_autonomy
  local set
  set=$(changed_set)
  case "$set" in
    none)
      if (( ${#FAILS[@]} > 0 )); then
        printf '%s\n' "${FAILS[@]}"
        exit 1
      fi
      echo "verify.sh: autonomy: automated checks passed; human review of the public-file scope is still required (unrelated-project mentions outside the closed patterns, RU/EN content correspondence)"
      echo "verify.sh: OK"
      exit 0
      ;;
    rules)
      fail "структурные правила изменены, парсер — нет. Действия агента (хук умеет только печатать текст; решение принимает агент):
  (a) приведи scripts/structure-parser.sh в соответствие с workflow/file-structure-rules.ru.md и коммить оба файла вместе; ИЛИ
  (b) если изменение правил не требует правки парсера — запроси у пользователя разрешение на коммит с --no-verify стандартными средствами харнесса (permission request). Без явного разрешения пользователя обход гейта запрещён.
  / structure rules changed, parser not updated. Agent actions (this hook can only print text; the agent decides):
  (a) bring scripts/structure-parser.sh in line with workflow/file-structure-rules.ru.md and commit both files together; OR
  (b) if the rules change requires no parser change, ask the user for permission to commit with --no-verify via the harness's standard permission-request mechanism. Bypassing the gate without explicit user permission is forbidden."
      ;;
    parser|both)
      run_parser_tests || true
      ;;
  esac
  if (( ${#FAILS[@]} > 0 )); then
    printf '%s\n' "${FAILS[@]}"
    exit 1
  fi
  echo "verify.sh: OK"
  exit 0
}

main "$@"
