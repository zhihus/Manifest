#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
exec bash "$ROOT/skills/manifest-init/scripts/install.sh" --templates "$ROOT/skills/manifest-init/templates" "$@"
