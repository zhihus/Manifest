#!/usr/bin/env bash
# Manifest framework — structure parser.
# Validates one Markdown document against the structure rules
# (workflow/file-structure-rules.ru.md). All logic lives here; the
# rules define WHAT is checked, this script grows with them.
#
# Usage: structure-parser.sh <file.md>
#        structure-parser.sh --dir <directory>
#   <file.md>  Markdown document to validate
#   --dir      Recursively validate regular *.md files (no symlink traversal)
# Exit codes: 0 clean, 1 violations found, 2 usage error.
set -euo pipefail

FILE=""
declare -a ORIG=()       # original lines
declare -a LEN=()        # line lengths (after \r strip)
declare -a CLASS=()      # per-line classification
declare -a VIOL=()       # buffered violations

# --- classify_line: assign one class per line ---
# classes: blank, heading, metadata, fence, label, example, other
classify_line() {
  local n=${#ORIG[@]} i line infence=0 level
  for ((i=0; i<n; i++)); do
    line="${ORIG[i]%$'\r'}"
    if [[ "$line" == '```'* ]]; then
      if (( infence )); then infence=0; else infence=1; fi
      CLASS+=("fence")
      continue
    fi
    if (( infence )); then CLASS+=("fence"); continue; fi
    if [[ -z "${line//[$'\t' ]/}" ]]; then CLASS+=("blank"); continue; fi
    if [[ "$line" =~ ^#{1,6}[[:space:]] ]]; then
      CLASS+=("heading"); continue
    fi
    if [[ "$line" == '>'*' '** ]]; then CLASS+=("metadata"); continue; fi
    if [[ "$line" == 'Правильно' || "$line" == 'Неправильно' \
          || "$line" == 'Correct' || "$line" == 'Incorrect' ]]; then
      CLASS+=("label"); continue
    fi
    if [[ "$line" == '✅'* || "$line" == '❌'* ]]; then
      CLASS+=("example"); continue
    fi
    CLASS+=("other")
  done
}

# --- check_regions: header lines 1-10, numbered body, examples footer ---
check_regions() {
  local i n=${#ORIG[@]} inbody=0 infooter=0
  if (( n < 10 )); then
    VIOL+=("$FILE:$n: regions: в документе меньше 10 строк шапки / document must have at least 10 header lines")
    return
  fi
  # header region: structural landmarks on fixed lines (1-based)
  [[ "${ORIG[0]%$'\r'}" == '#'*' '* ]] || \
    VIOL+=("$FILE:1: regions: строка 1 должна быть заголовком уровня 1 / line 1 must be a level-1 title heading")
  case "${ORIG[2]%$'\r'}" in
    '# Метаданные'|'# Metadata') : ;;
    *) VIOL+=("$FILE:3: regions: строка 3 должна быть '# Метаданные' / line 3 must be '# Метаданные' / '# Metadata'") ;;
  esac
  for i in 3 4 5 6; do
    [[ "${CLASS[i]}" == "metadata" ]] || \
      VIOL+=("$FILE:$((i+1)): regions: строка $((i+1)) должна быть строкой метаданных / line $((i+1)) must be a metadata line")
  done
  case "${ORIG[8]%$'\r'}" in
    '# Описание'|'# Description') : ;;
    *) VIOL+=("$FILE:9: regions: строка 9 должна быть '# Описание' / line 9 must be '# Описание' / '# Description'") ;;
  esac
  [[ "${CLASS[9]}" != "blank" ]] || \
    VIOL+=("$FILE:10: regions: строка 10 должна быть непустым текстом описания / line 10 must be non-empty description text")
  # numbered ## sections after the header: body, then Примеры = footer
  for ((i=10; i<n; i++)); do
    [[ "${CLASS[i]}" == "fence" ]] && continue
    local line="${ORIG[i]%$'\r'}"
    [[ "$line" == '## '* ]] || continue
    if [[ "$line" == '## '*Примеры* || "$line" == '## '*Examples* ]]; then
      infooter=1; continue
    fi
    if (( infooter )); then
      VIOL+=("$FILE:$((i+1)): regions: нумерованный раздел внутри подвала / numbered section inside the footer region")
    else
      inbody=1
    fi
  done
}

# --- parse_args: exactly one file argument ---
parse_args() {
  if [[ $# -lt 1 ]]; then
    echo "Использование / Usage: structure-parser.sh <file.md>" >&2
    exit 2
  fi
  FILE="$1"
  if [[ ! -f "$FILE" ]]; then
    echo "ОШИБКА: файл не существует / ERROR: file does not exist: $FILE" >&2
    exit 2
  fi
}

# --- load_lines: read file into arrays, strip \r for checks ---
load_lines() {
  local line stripped
  while IFS= read -r line || [[ -n "$line" ]]; do
    ORIG+=("$line")
    stripped="${line%$'\r'}"
    LEN+=("${#stripped}")
  done < "$FILE"
}

# --- check_labels: labels are text, examples need a preceding label ---
check_labels() {
  local i n=${#ORIG[@]} infence=0 lastlabel="" lastlabelhead=0
  for ((i=0; i<n; i++)); do
    local c="${CLASS[i]}"
    [[ "$c" == "fence" ]] && { infence=1; continue; }
    [[ "$c" == "blank" ]] && infence=0
    if [[ "$c" == "heading" ]]; then
      lastlabel=""; lastlabelhead=0
      continue
    fi
    if [[ "$c" == "label" ]]; then
      lastlabel="${ORIG[i]%$'\r'}"; lastlabelhead=0
      continue
    fi
    if [[ "$c" == "example" ]]; then
      if [[ -z "$lastlabel" ]]; then
        VIOL+=("$FILE:$((i+1)): labels: строка примера без метки Правильно/Неправильно (Correct/Incorrect) / example line has no preceding Правильно/Неправильно label")
      fi
      continue
    fi
  done
  # a heading acting as a label is detected via heading text
  for ((i=0; i<n; i++)); do
    local line="${ORIG[i]%$'\r'}"
    [[ "${CLASS[i]}" == "heading" ]] || continue
    if [[ "$line" == *'Неправильные'* || "$line" == *'Правильные'* ]]; then
      VIOL+=("$FILE:$((i+1)): labels: метка должна быть текстом, не заголовком / label must be plain text, not a heading: $line")
    fi
  done
}

# --- check_examples: example lines start with the correct symbol ---
check_examples() {
  local i n=${#ORIG[@]} infence=0
  for ((i=0; i<n; i++)); do
    [[ "${CLASS[i]}" == "fence" ]] && { infence=1; continue; }
    [[ "${CLASS[i]}" == "blank" ]] && infence=0
    (( infence )) && continue
    local line="${ORIG[i]%$'\r'}"
    if [[ "${CLASS[i]}" == "example" ]]; then
      if [[ "$line" != '✅'* && "$line" != '❌'* ]]; then
        VIOL+=("$FILE:$((i+1)): examples: строка примера должна начинаться с ✅ или ❌ / example line must start with ✅ or ❌")
      fi
    fi
  done
}

# --- check_logical_lines: multi-line logical strings per rule 2.3 ---
check_logical_lines() {
  local i n=${#ORIG[@]} infence=0
  # blank line inside metadata lines 4-7 (1-based) is a violation
  for i in 3 4 5 6; do
    (( i < n )) || return
    [[ "${CLASS[i]}" == "blank" ]] && \
      VIOL+=("$FILE:$((i+1)): logical-lines: пустая строка внутри блока метаданных (правило 2.3) / blank line inside the metadata block (rule 2.3)")
  done
  # a heading continued on the next physical line is a violation
  for ((i=0; i<n; i++)); do
    [[ "${CLASS[i]}" == "fence" ]] && { infence=1; continue; }
    [[ "${CLASS[i]}" == "blank" ]] && infence=0
    (( infence )) && continue
    if [[ "${CLASS[i]}" == "heading" ]] && (( i+1 < n )) \
       && [[ "${CLASS[i+1]}" == "other" ]] \
       && [[ "${ORIG[i]%$'\r'}" =~ ^#{2,6}[[:space:]] ]]; then
       VIOL+=("$FILE:$((i+2)): logical-lines: заголовок продолжается на следующей строке (правило 2.3) / heading continues on the next line (rule 2.3)")
    fi
  done
  # wrapped description (lines 10+) and wrapped body text are one
  # logical line by design: no violation for the wrap itself
}

# --- check_header: header layout per templates 3.1-3.8 ---
check_header() {
  local n=${#ORIG[@]} i title
  (( n >= 10 )) || return
  title="${ORIG[0]%$'\r'}"
  title="${title#\# }"            # strip the level-1 markup "# "
  local words
  words=$(wc -w <<< "$title")
  if (( ${#title} > 35 || words > 5 )); then
    VIOL+=("$FILE:1: header: заголовок длиннее 5 слов или 35 символов / title exceeds 5 words or 35 characters (rule 3.1)")
  fi
  for i in 3 4 5 6; do
    local line="${ORIG[i]%$'\r'}"
    if [[ "$line" == '>'*' '** ]]; then
      [[ "$line" == *'  ' ]] || \
        VIOL+=("$FILE:$((i+1)): header: нет двух завершающих пробелов / metadata line lacks two trailing spaces (template 3.3-3.6)")
    fi
  done
  [[ -n "${ORIG[9]%$'\r'}" ]] || \
    VIOL+=("$FILE:10: header: текст описания пуст / description text is empty (rule 3.8)")
}

# --- check_metadata_values: values per 3.3-3.6 ---
check_metadata_values() {
  local n=${#ORIG[@]} i line
  (( n >= 7 )) || return
  line="${ORIG[3]%$'\r'}"
  [[ "$line" =~ ^\>\ \*\*Status:\ (draft|approved|archived)\*\*[[:space:]]{2}$ ]] || \
    VIOL+=("$FILE:4: metadata-values: Status должен быть draft, approved или archived / Status must be draft, approved or archived (rule 3.3)")
  line="${ORIG[4]%$'\r'}"
  [[ "$line" =~ ^\>\ \*\*Type:\ document\*\*[[:space:]]{2}$ ]] || \
    VIOL+=("$FILE:5: metadata-values: Type должен быть document / Type must be document (rule 3.4)")
  line="${ORIG[5]%$'\r'}"
  [[ "$line" =~ ^\>\ \*\*Version:\ [0-9]+\.[0-9]+\.[0-9]+\*\*[[:space:]]{2}$ ]] || \
    VIOL+=("$FILE:6: metadata-values: Version должна соответствовать X.Y.Z / Version must match X.Y.Z (rule 3.5)")
  line="${ORIG[6]%$'\r'}"
  [[ "$line" =~ ^\>\ \*\*Updated:\ [0-9]{4}-[0-9]{2}-[0-9]{2}\*\*[[:space:]]{2}$ ]] || \
    VIOL+=("$FILE:7: metadata-values: Updated должна соответствовать ISO YYYY-MM-DD / Updated must match ISO YYYY-MM-DD (rule 3.6)")
}

# --- check_heading_numbering: hierarchy and continuity per 2.3 ---
check_heading_numbering() {
  local n=${#ORIG[@]} i line inheader=1 infence=0
  local -A SECT=() SUB=()
  local SECT_LAST=0 SUB_LAST=0 lvl num s
  for ((i=0; i<n; i++)); do
    [[ "${CLASS[i]}" == "fence" ]] && { infence=1; continue; }
    [[ "${CLASS[i]}" == "blank" ]] && infence=0
    (( infence )) && continue
    line="${ORIG[i]%$'\r'}"
    [[ "${CLASS[i]}" == "heading" ]] || continue
    if (( inheader )) && [[ ! "$line" =~ ^##[[:space:]] ]]; then
      # level-1 headings are allowed only in the header (lines 1-10)
      if (( i+1 > 10 )) && [[ "$line" =~ ^#[[:space:]] ]]; then
        VIOL+=("$FILE:$((i+1)): numbering: заголовок уровня 1 вне региона шапки / level-1 heading outside the header region (rule 2.2)")
      fi
      continue
    fi
    inheader=0
    case "$line" in
      '## '*)  lvl=2 ;;
      '### '*) lvl=3 ;;
      '#### '*) lvl=4 ;;
      *) continue ;;
    esac
    num="${line:lvl+1}"                  # text after the marks+space
    if (( lvl == 2 )); then
      num="${num%%.*}"
      if [[ ! "$num" =~ ^[0-9]+$ ]]; then
        VIOL+=("$FILE:$((i+1)): numbering: номер заголовка отсутствует или неверен / heading number missing or malformed (rule 2.2)")
        continue
      fi
      if [[ -n "${SECT[$num]:-}" ]]; then
        VIOL+=("$FILE:$((i+1)): numbering: дублирующийся номер раздела $num / duplicate section number $num (rule 2.2)")
      fi
      if (( SECT_LAST > 0 && num != SECT_LAST + 1 )); then
        VIOL+=("$FILE:$((i+1)): numbering: пропуск нумерации разделов: ожидался $((SECT_LAST+1)), получен $num / section numbering gap: expected $((SECT_LAST+1)), got $num (rule 2.2)")
      fi
      SECT[$num]=1; SECT_LAST=$num; SUB_LAST=0
    else
      # level 3: full "N.M" number; level 4: format check only
      s="${num%%.*}"
      local m="${num#*.}"                # strip N.
      m="${m%%.*}"                       # take M (drop .K if present)
      if [[ ! "$s" =~ ^[0-9]+$ || ! "$m" =~ ^[0-9]+$ ]]; then
        VIOL+=("$FILE:$((i+1)): numbering: номер заголовка отсутствует или неверен / heading number missing or malformed (rule 2.2)")
        continue
      fi
      if (( lvl == 4 )); then
        continue
      fi
      if [[ -n "${SUB[$num]:-}" ]]; then
        VIOL+=("$FILE:$((i+1)): numbering: дублирующийся номер подраздела $num / duplicate subsection number $num (rule 2.2)")
      fi
      if (( s == SECT_LAST && SUB_LAST > 0 && m != SUB_LAST + 1 )); then
        VIOL+=("$FILE:$((i+1)): numbering: пропуск нумерации подразделов: ожидался $s.$((SUB_LAST+1)), получен $num / subsection numbering gap: expected $s.$((SUB_LAST+1)), got $num (rule 2.2)")
      fi
      SUB[$num]=1; SUB_LAST=$m
    fi
  done
}

# --- check_heading_length: one physical line, <=100 chars ---
check_heading_length() {
  local n=${#ORIG[@]} i
  for ((i=0; i<n; i++)); do
    [[ "${CLASS[i]}" == "heading" ]] || continue
    if (( LEN[i] > 100 )); then
      VIOL+=("$FILE:$((i+1)): heading-length: заголовок содержит ${LEN[i]} символов / heading is ${LEN[i]} characters (rule 4.1)")
    fi
    if (( i+1 < n )) && [[ "${CLASS[i+1]}" == "other" ]] \
       && [[ "${ORIG[i]%$'\r'}" =~ ^#{2,6}[[:space:]] ]]; then
      :  # continuation handled by check_logical_lines
    fi
  done
}

# --- report: print violations sorted, set exit code ---
report() {
  if (( ${#VIOL[@]} == 0 )); then
    exit 0
  fi
  printf '%s\n' "${VIOL[@]}" | sort -t: -k2,2n
  exit 1
}

# --- main: pipeline ---
main() {
  parse_args "$@"
  load_lines
  classify_line
  check_regions
  check_labels
  check_examples
  check_logical_lines
  check_header
  check_metadata_values
  check_heading_numbering
  check_heading_length
  report
}

# --- directory mode: validate every regular Markdown file ---
run_directory() {
  local directory="$1" file count=0 result=0 rc
  if [[ ! -d "$directory" || ! -r "$directory" ]]; then
    echo "ОШИБКА: каталог недоступен / ERROR: directory is not accessible: $directory" >&2
    return 2
  fi
  directory="$(cd "$directory" 2>/dev/null && pwd)" || {
    echo "ОШИБКА: не удалось открыть каталог / ERROR: cannot enter directory: $directory" >&2
    return 2
  }
  while IFS= read -r -d '' file; do
    count=$((count + 1))
    if "$SCRIPT_PATH" "$file"; then
      :
    else
      rc=$?
      if (( rc == 2 )); then
        result=2
      elif (( rc == 1 && result == 0 )); then
        result=1
      fi
    fi
  done < <(find "$directory" -type f -name '*.md' -print0)
  if (( count == 0 )); then
    echo "ОШИБКА: Markdown-файлы не найдены / ERROR: no Markdown files found: $directory" >&2
    return 2
  fi
  printf 'Проверено Markdown-файлов / Markdown files checked: %s\n' "$count"
  return "$result"
}

SCRIPT_PATH="$0"
if [[ "$SCRIPT_PATH" != */* ]]; then
  SCRIPT_PATH="$(command -v "$SCRIPT_PATH")"
fi
SCRIPT_PATH="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)/$(basename "$SCRIPT_PATH")"

if [[ "${1:-}" == "--dir" ]]; then
  if (( $# != 2 )); then
    echo "Использование / Usage: structure-parser.sh --dir <directory>" >&2
    exit 2
  fi
  if run_directory "$2"; then
    exit 0
  else
    exit $?
  fi
fi

main "$@"
