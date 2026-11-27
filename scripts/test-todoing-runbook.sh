#!/usr/bin/env bash
# Regression checks for the bilingual Todoing integration runbook.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RU="$ROOT/workflow/README.ru.md"
EN="$ROOT/workflow/README.en.md"
BOOTSTRAP="$ROOT/skills/manifest-init/references/todoing-bootstrap.md"
FAIL=0

fail() {
  printf 'FAIL %s\n' "$1"
  FAIL=1
}

require_text() {
  local file=$1 needle=$2 label=$3
  if ! grep -Fq -- "$needle" "$file"; then
    fail "$label: missing '$needle' in ${file#"$ROOT"/}"
  fi
}

forbid_text() {
  local file=$1 needle=$2 label=$3
  if grep -Fq -- "$needle" "$file"; then
    fail "$label: unsafe text '$needle' in ${file#"$ROOT"/}"
  fi
}

require_order() {
  local file=$1 label=$2
  shift 2
  local previous=0 line needle
  for needle in "$@"; do
    line=$(grep -nF -- "$needle" "$file" | head -n 1 | cut -d: -f1 || true)
    if [[ -z $line ]]; then
      fail "$label: missing '$needle'"
      return
    fi
    if (( line <= previous )); then
      fail "$label: '$needle' is out of order"
      return
    fi
    previous=$line
  done
}

require_text "$BOOTSTRAP" "todoing --json api" "bootstrap JSON API CLI syntax"
require_text "$BOOTSTRAP" "6acca6087fbd4b39ad0dcd5f12db52dc4d84b163" "bootstrap compatible Todoing build"
forbid_text "$BOOTSTRAP" "todoing api --json" "incorrect bootstrap JSON API CLI syntax"

for file in "$RU" "$EN"; do
  require_text "$file" "todoing --json api" "JSON API CLI syntax"
  forbid_text "$file" "todoing api --json" "incorrect JSON API CLI syntax"
  require_text "$file" "6acca6087fbd4b39ad0dcd5f12db52dc4d84b163" "compatible Todoing build"
done

for file in "$RU" "$EN"; do
  [[ -f $file ]] || { fail "missing runbook: $file"; continue; }
  for op in \
    store.init store.info store.verify task.create task.external-ref.add \
    task.version.approve task.lock.acquire task.lock.heartbeat \
    task.lock.release task.lock.recover task.status.set task.review.add \
    task.commit.finalize task.cancel task.dependency.list task.get task.version.list \
    task.history.list task.review.list task.external-ref.list; do
    require_text "$file" "$op" "API contract"
  done
  for op in store.snapshot store.snapshot.verify store.snapshot.restore; do
    require_text "$file" "$op" "snapshot API"
  done
  for value in backlog ready in_progress review verified completed; do
    require_text "$file" "$value" "status mapping"
  done
  require_text "$file" "720" "lease duration"
  require_text "$file" "heartbeat_seconds = 60" "heartbeat configuration"
  require_text "$file" "60" "recovery grace"
  require_text "$file" "ready → in_progress" "execution status transition"
  require_text "$file" "openspec archive <change-id> --yes --skip-specs" "cancel archive mode"
done
require_text "$RU" "только Todoing SQLite" "snapshot restore boundary"
require_text "$RU" "только по явному разрешению пользователя" "explicit restore approval"
require_text "$RU" "expected_sha256" "restore checksum binding"
require_text "$RU" "safety snapshot" "pre-restore safety snapshot"
require_text "$RU" "при активных task locks" "snapshot lock guard"
require_text "$EN" "only Todoing SQLite" "snapshot restore boundary"
require_text "$EN" "only with explicit user approval" "explicit restore approval"
require_text "$EN" "expected_sha256" "restore checksum binding"
require_text "$EN" "safety snapshot" "pre-restore safety snapshot"
require_text "$EN" "while task locks are active" "snapshot lock guard"

require_text "$RU" "только после явного одобрения пользователя" "user approval gate"
require_text "$RU" "Субагент не получает token" "token custody"
require_text "$RU" "не перезаписывайте" "no-overwrite rule"
require_text "$RU" "сначала сверяйте фактическое состояние" "reconciliation before retry"
require_text "$RU" 'outcome должен быть `completed`' "dependency readiness gate"
require_text "$RU" "store уже существует, а конфиг отсутствует — остановитесь" "existing store configuration guard"
require_text "$EN" "only after explicit user approval" "user approval gate"
require_text "$EN" "Never give the token to a role agent" "token custody"
require_text "$EN" "Never overwrite an existing config" "no-overwrite rule"
require_text "$EN" "first reconcile actual" "reconciliation before retry"
require_text "$EN" 'outcome `completed`' "dependency readiness gate"
require_text "$EN" "store already exists but the config is missing, stop" "existing store configuration guard"
require_text "$RU" "Режим Todoing без OpenSpec" "Todoing-only workflow"
require_text "$RU" "task.list" "Todoing-only task discovery"
require_text "$RU" "самостоятельного результата работы" "no subtask explosion"
require_text "$RU" "task.commit.add" "Todoing-only commit traceability"
require_text "$RU" "не используются" "no OpenSpec dependency"
require_text "$EN" "Todoing-only mode (OpenSpec disabled)" "Todoing-only workflow"
require_text "$EN" "independently meaningful" "no subtask explosion"
require_text "$EN" "task.commit.add" "Todoing-only commit traceability"
require_text "$EN" "Do not run OpenSpec archive" "no OpenSpec dependency"

forbid_text "$RU" 'автоматически выполните `store.init`' "no store overwrite"
forbid_text "$EN" 'automatically run `store.init` over an existing store' "no store overwrite"
forbid_text "$RU" 'выполните `task.lock.release` без проверки владения' "no blind lock release"
forbid_text "$EN" 'release the lock without confirming ownership' "no blind lock release"

RU_TODOING_ONLY=$(mktemp)
EN_TODOING_ONLY=$(mktemp)
sed -n '/^### 6\.2\.1\./,/^### 6\.3\./p' "$RU" > "$RU_TODOING_ONLY"
sed -n '/^### 6\.2\.1\./,/^### 6\.3\./p' "$EN" > "$EN_TODOING_ONLY"
if grep -Fq 'openspec archive <change-id>' "$RU_TODOING_ONLY" "$EN_TODOING_ONLY"; then
  fail "Todoing-only mode must not execute OpenSpec archive"
fi

RU_COMPLETION=$(mktemp)
EN_COMPLETION=$(mktemp)
RU_RECOVERY=$(mktemp)
EN_RECOVERY=$(mktemp)
RU_CANCELLATION=$(mktemp)
EN_CANCELLATION=$(mktemp)
trap 'rm -f "$RU_TODOING_ONLY" "$EN_TODOING_ONLY" "$RU_COMPLETION" "$EN_COMPLETION" "$RU_RECOVERY" "$EN_RECOVERY" "$RU_CANCELLATION" "$EN_CANCELLATION"' EXIT

sed -n '/^### 6\.5\./,/^### 6\.6\./p' "$RU" > "$RU_COMPLETION"
sed -n '/^### 6\.5\./,/^### 6\.6\./p' "$EN" > "$EN_COMPLETION"
sed -n '/^### 6\.7\./,$p' "$RU" > "$RU_RECOVERY"
sed -n '/^### 6\.7\./,$p' "$EN" > "$EN_RECOVERY"
sed -n '/Любой агент может рекомендовать отмену/,$p' "$RU_COMPLETION" > "$RU_CANCELLATION"
sed -n '/Any agent may recommend cancellation/,$p' "$EN_COMPLETION" > "$EN_CANCELLATION"

require_order "$RU_COMPLETION" "Russian completion sequence" \
  "Review approved" "Acceptance checks" "openspec archive <change-id> --yes" "Git merge" \
  "task.commit.finalize" "task.status.set" "task.lock.release"
require_order "$EN_COMPLETION" "English completion sequence" \
  "Review approved" "Acceptance checks" "openspec archive <change-id> --yes" "Git merge" \
  "task.commit.finalize" "task.status.set" "task.lock.release"

require_order "$RU_CANCELLATION" "Russian cancellation sequence" \
  "task.cancel" "openspec archive <change-id> --yes --skip-specs" "task.lock.release"
require_order "$EN_CANCELLATION" "English cancellation sequence" \
  "task.cancel" "openspec archive <change-id> --yes --skip-specs" "task.lock.release"

require_order "$RU_RECOVERY" "Russian lost-release recovery" \
  "task.lock.heartbeat" "успешного подтверждения владения"
require_order "$EN_RECOVERY" "English lost-release recovery" \
  "task.lock.heartbeat" "ownership is confirmed"

if (( FAIL )); then
  exit 1
fi

python3 "$ROOT/scripts/test-todoing-config.py"

echo "PASS bilingual Todoing runbook contract"
