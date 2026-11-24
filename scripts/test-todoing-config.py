#!/usr/bin/env python3
"""Validate the bilingual Todoing TOML configuration examples."""
from pathlib import Path
import re
import tomllib

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = {
    "ru": r"Рекомендуемое содержимое `.todoing/config.toml` для нового проекта:\n\n```toml\n(.*?)\n```",
    "en": r"Recommended `.todoing/config.toml` for a new project:\n\n```toml\n(.*?)\n```",
}

def extract(language: str) -> dict:
    path = ROOT / "workflow" / ("README.ru.md" if language == "ru" else "README.en.md")
    text = path.read_text(encoding="utf-8")
    match = re.search(PATTERNS[language], text, re.DOTALL)
    if not match:
        raise SystemExit(f"FAIL {language}: TOML configuration block not found")
    try:
        return tomllib.loads(match.group(1))
    except tomllib.TOMLDecodeError as exc:
        raise SystemExit(f"FAIL {language}: invalid TOML: {exc}") from exc

ru = extract("ru")
en = extract("en")
if ru != en:
    raise SystemExit("FAIL Russian and English TOML configurations differ")

assert ru.get("format_version") == 1, "format_version must be 1"
assert ru.get("locking") == {
    "lease_seconds": 720,
    "heartbeat_seconds": 180,
    "recovery_grace_seconds": 60,
}, "locking values do not match the approved lease protocol"

statuses = ru.get("statuses", [])
expected_statuses = ["backlog", "ready", "in_progress", "review", "verified", "completed"]
assert [item.get("id") for item in statuses] == expected_statuses, "status order or IDs differ"
assert all(item.get("enabled") is True for item in statuses), "all workflow statuses must be enabled"
assert [item.get("id") for item in statuses if "outcome" in item] == ["completed"], "only completed may define an outcome"
assert statuses[-1].get("outcome") == "completed", "completed status must map to completed outcome"

transitions = ru.get("transitions", [])
expected_transitions = [
    ("backlog", "ready"),
    ("ready", "in_progress"),
    ("in_progress", "review"),
    ("review", "in_progress"),
    ("review", "verified"),
    ("verified", "completed"),
]
assert [(item.get("from"), item.get("to")) for item in transitions] == expected_transitions, "status transition graph differs"

print("PASS bilingual Todoing TOML configuration")
