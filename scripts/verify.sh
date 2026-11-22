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
  python - "$VERIFY_TMP" > /dev/null <<'EOF'
import sys
fixture = (
    "# T" + "e" * 140 + "\n"
    "\n"
    "# \u041c\u0435\u0442\u0430\u0434\u0430\u043d\u043d\u044b\u0435\n"
    "> **Status: in-development**  \n"
    "> **Type: document**  \n"
    "> **Version: 1.0**  \n"
    "> **Updated: 2026-11-09**  \n"
    "\n"
    "# \u041e\u043f\u0438\u0441\u0430\u043d\u0438\u0435\n"
    "Text.\n"
    "\n"
    "## 1. \u041f\u0435\u0440\u0432\u044b\u0439\n"
    "\n"
    "## 3. \u0412\u0442\u043e\u0440\u043e\u0439\n"
    "\n"
    "### 3.1. \u041d\u0435\u043f\u0440\u0430\u0432\u0438\u043b\u044c\u043d\u044b\u0435\n"
    "\n"
    "\u274c \u043f\u0440\u0438\u043c\u0435\u0440 \u0431\u0435\u0437 \u043c\u0435\u0442\u043a\u0438\n"
)
open(sys.argv[1] + "/fixture.md", "w", encoding="utf-8", newline="\n").write(fixture)
EOF
  if bash "$ROOT/$PARSER" "$VERIFY_TMP/fixture.md" > /dev/null 2>&1; then
    rc=1
    fail "парсер не нашёл заложенные нарушения / parser missed the seeded violations"
  fi
  return $rc
}

# --- 4. main: branches per the agreed model ---
main() {
  check_existence
  local set
  set=$(changed_set)
  case "$set" in
    none)
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
