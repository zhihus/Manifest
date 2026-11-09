#!/usr/bin/env bash
# Manifest framework — structure parser.
# Validates one Markdown document against the structure rules
# (workflow/file-structure-rules.ru.md). All logic lives here; the
# rules define WHAT is checked, this script grows with them.
#
# Usage: structure-parser.sh <file.md>
#   <file.md>  Markdown document to validate
# Exit codes: 0 clean, 1 violations found, 2 usage error.
set -euo pipefail

FILE=""
declare -a ORIG=()       # original lines
declare -a LEN=()        # line lengths (after \r strip)
declare -a VIOL=()       # buffered violations

# --- parse_args: exactly one file argument ---
parse_args() {
  if [[ $# -lt 1 ]]; then
    echo "Usage: structure-parser.sh <file.md>" >&2
    exit 2
  fi
  FILE="$1"
  if [[ ! -f "$FILE" ]]; then
    echo "ERROR: file does not exist: $FILE" >&2
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

# --- check_line_length: 100-char limit per line ---
check_line_length() {
  local i
  for i in "${!LEN[@]}"; do
    if (( LEN[i] > 100 )); then
      VIOL+=("$FILE:$((i+1)): line-length: line is ${LEN[i]} characters (limit 100)")
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
  check_line_length
  report
}

main "$@"
