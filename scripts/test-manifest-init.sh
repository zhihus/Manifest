#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
exec bash "$ROOT/skills/manifest-init/tests/test-install.sh" "$@"
