#!/usr/bin/env bash
# Regression checks for the bilingual Todoing integration runbook.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
RU="$ROOT/workflow/README.ru.md"
EN="$ROOT/workflow/README.en.md"
BOOTSTRAP="$ROOT/skills/manifest-init/references/todoing-bootstrap.md"
SKILL="$ROOT/skills/manifest-init/SKILL.md"
TODOING_AGENT="$ROOT/skills/manifest-init/references/todoing-agent-workflow.md"
RUNBOOK_SPEC="$ROOT/openspec/specs/manifest-todoing-runbook/spec.md"
CONTRACT_RU="$ROOT/docs/architecture/todoing-contract.ru.md"
CONTRACT_EN="$ROOT/docs/architecture/todoing-contract.en.md"
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

require_text "$CONTRACT_RU" '`todoing --json api`' "Russian contract JSON API CLI syntax"
require_text "$CONTRACT_EN" '`todoing --json api`' "English contract JSON API CLI syntax"
forbid_text "$CONTRACT_RU" "todoing api --json" "incorrect Russian contract CLI syntax"
forbid_text "$CONTRACT_EN" "todoing api --json" "incorrect English contract CLI syntax"

require_text "$SKILL" "manage Todoing tasks in a connected project" "runtime skill trigger"
require_text "$SKILL" "Choose exactly one procedure" "skill mode selection"
require_text "$SKILL" "Connection procedure" "skill connection mode"
require_text "$SKILL" "Do not run the installer as part of ordinary task management" "no installer rerun"

require_text "$SKILL" "references/todoing-agent-workflow.md" "runtime skill reference"
require_text "$TODOING_AGENT" "todoing --json api" "runtime JSON API CLI syntax"
require_text "$TODOING_AGENT" "653788a954d2a120db1beba854308982814d8222" "runtime compatible Todoing build"
require_text "$TODOING_AGENT" "task.list" "runtime task discovery"
require_text "$TODOING_AGENT" "task.create" "runtime task creation"
require_text "$TODOING_AGENT" "task.update" "runtime task updates"
require_text "$TODOING_AGENT" "task.dependency.add" "runtime dependency management"
require_text "$TODOING_AGENT" "task.lock.acquire" "runtime lock management"
require_text "$TODOING_AGENT" "task.review.add" "runtime Review management"
require_text "$TODOING_AGENT" "task.commit.finalize" "runtime task completion"
require_text "$TODOING_AGENT" "Do not heartbeat while the role agent is running" "heartbeat must not run during agent execution"
require_text "$TODOING_AGENT" "separate role/session" "independent Reviewer"
require_text "$TODOING_AGENT" "revision_count" "revision counter semantics"
require_text "$TODOING_AGENT" "review → in_progress" "review return transition"
require_text "$TODOING_AGENT" "openspec archive <change-id> --yes" "successful OpenSpec archive"
require_text "$TODOING_AGENT" "openspec archive <change-id> --yes --skip-specs" "cancellation archive without spec merge"
require_text "$TODOING_AGENT" "Only the user may approve it" "user-only cancellation authority"
require_text "$TODOING_AGENT" "task.external-ref.list" "cross-system recovery reconciliation"
for scenario in "After OpenSpec archive but before Git merge" "After Git merge but before final commit marker" "During cancellation"; do
  require_text "$TODOING_AGENT" "$scenario" "partial failure recovery"
done
for scenario in "Failure after OpenSpec archive" "Failure after Git merge" "Failure after task completion" "Lease expires during agent execution" "Partial cancellation"; do
  require_text "$RUNBOOK_SPEC" "$scenario" "normative recovery scenario"
done

require_text "$TODOING_AGENT" '`actor_id` is attribution, not authentication' "runtime trust boundary"
require_text "$TODOING_AGENT" "Todoing/OpenSpec registration" "runtime OpenSpec coordination"
require_text "$TODOING_AGENT" "task.external-ref.add" "OpenSpec task reference"
require_text "$TODOING_AGENT" "exact OpenSpec" "OpenSpec change identity"
require_text "$TODOING_AGENT" "task.version.approve" "approved baseline"
require_text "$TODOING_AGENT" "exclusively in that change's `tasks.md`" "OpenSpec task decomposition"
forbid_text "$TODOING_AGENT" "frozen next stage" "obsolete runtime OpenSpec boundary"
require_text "$TODOING_AGENT" "does not modify project context files" "context templates remain untouched"
require_text "$SKILL" "Do not copy this reference into project context files" "runtime workflow stays in skill package"
require_text "$SKILL" "Todoing/OpenSpec coordination path" "runtime OpenSpec coordination path"
require_text "$RUNBOOK_SPEC" "Manage coordinated Todoing and OpenSpec work after connection" "normative runtime OpenSpec scenario"
require_text "$RUNBOOK_SPEC" "registers exactly one Backlog Todoing task" "normative task registration"
forbid_text "$RUNBOOK_SPEC" "stage 2 is frozen" "obsolete normative stage boundary"
forbid_text "$SKILL" "frozen next stage" "obsolete runtime OpenSpec boundary"

forbid_text "$TODOING_AGENT" "todoing api --json" "incorrect runtime JSON API CLI syntax"

require_text "$BOOTSTRAP" "todoing --json api" "bootstrap JSON API CLI syntax"
require_text "$BOOTSTRAP" "653788a954d2a120db1beba854308982814d8222" "bootstrap compatible Todoing build"
forbid_text "$BOOTSTRAP" "todoing api --json" "incorrect bootstrap JSON API CLI syntax"

for file in "$RU" "$EN"; do
  require_text "$file" "todoing --json api" "JSON API CLI syntax"
  forbid_text "$file" "todoing api --json" "incorrect JSON API CLI syntax"
  require_text "$file" "653788a954d2a120db1beba854308982814d8222" "compatible Todoing build"
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
require_text "$RU" "actor_id" "actor attribution boundary"
require_text "$RU" "принятой процедурной границей полномочий" "honest role-access boundary"
require_text "$EN" "agreed procedural authority boundary" "honest role-access boundary"
for file in "$CONTRACT_RU" "$CONTRACT_EN"; do
  require_text "$file" "immediately before each blocking role-agent run" "heartbeat timing contract"
  require_text "$file" "Do not heartbeat while the role agent is executing" "no heartbeat during execution"
done
forbid_text "$CONTRACT_EN" "renew the lease while it is active" "obsolete heartbeat timing"
require_text "$CONTRACT_EN" "implemented in Todoing as generic mechanisms" "implemented generic Todoing APIs"

require_order "$TODOING_AGENT" "Agent coordinated completion sequence" \
  "## Completion" "openspec archive <change-id> --yes" "Merge Git" \
  "task.commit.finalize" "task.status.set" "task.lock.release"
require_order "$TODOING_AGENT" "Agent cancellation sequence" \
  "## Cancellation" "task.cancel" "openspec archive <change-id> --yes --skip-specs" \
  "task.lock.release"
for scenario in "S1 — after OpenSpec archive" "S2 — after Git merge" "S3 — after" "S4 — lease expires" "S5 — failure during cancellation"; do
  require_text "$RU" "$scenario" "Russian partial recovery scenario"
  require_text "$EN" "$scenario" "English partial recovery scenario"
done


require_text "$EN" "Never overwrite an existing config" "no-overwrite rule"
require_text "$EN" "first reconcile actual" "reconciliation before retry"
require_text "$EN" 'outcome `completed`' "dependency readiness gate"
require_text "$EN" "store already exists but the config is missing, stop" "existing store configuration guard"
require_text "$RU" "Режим Todoing без OpenSpec" "Todoing-only workflow"
require_text "$RU" "task.list" "Todoing-only task discovery"
require_text "$RU" "task.update" "Todoing-only task updates"
require_text "$RU" "task.dependency.add" "Todoing-only dependency management"
require_text "$RU" "task.dependency.remove" "Todoing-only dependency management"
require_text "$RU" "task.dependency.list" "Todoing-only dependency management"
require_text "$EN" "task.update" "Todoing-only task updates"
require_text "$EN" "task.dependency.add" "Todoing-only dependency management"
require_text "$EN" "task.dependency.remove" "Todoing-only dependency management"
require_text "$EN" "task.dependency.list" "Todoing-only dependency management"

require_text "$RU" "только для самостоятельного" "no subtask explosion"
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
