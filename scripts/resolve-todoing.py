#!/usr/bin/env python3
"""Resolve the Todoing binary for Manifest.

Strict priority order:

  1. Explicit TODOING_BIN (must point to an existing file)
  2. Portable build in the Manifest release cache
     (<cache>/portable/<VERSION>/<PLATFORM>-<ARCH>/todoing[.exe])
  3. `todoing` found on PATH

After resolution the binary's reported version is verified against
TODOING_REQUIRED_VERSION (default: 1.2.0). An incompatible version is a hard
stop — this resolver never silently falls back to another binary.

On success the resolved absolute path is printed on stdout, so the result can
be used as:  TODOING_BIN=$(py scripts/resolve-todoing.py)

Environment:
  TODOING_BIN                explicit binary path (highest priority)
  TODOING_CACHE_DIR          release cache root (default: <Manifest>/.todoing-cache)
  TODOING_REQUIRED_VERSION   required version (default: 1.2.0)
"""
from __future__ import annotations

import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = os.environ.get("TODOING_REQUIRED_VERSION", "1.2.0")
CACHE = Path(os.environ.get("TODOING_CACHE_DIR", str(ROOT / ".todoing-cache")))


def fail(message: str) -> "NoReturn":  # noqa: F821
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def detect_platform_arch() -> tuple[str, str, str]:
    system = platform.system().lower()
    if system == "windows":
        plat = "windows"
    elif system == "linux":
        plat = "linux"
    elif system == "darwin":
        plat = "macos"
    else:
        fail(f"unsupported OS: {system}")
    machine = platform.machine().lower()
    if machine in ("x86_64", "amd64"):
        arch = "x64"
    elif machine in ("aarch64", "arm64"):
        arch = "arm64"
    else:
        fail(f"unsupported arch: {machine}")
    exe = ".exe" if plat == "windows" else ""
    return plat, arch, exe


def resolve() -> tuple[Path, str]:
    todoing_bin = os.environ.get("TODOING_BIN")
    if todoing_bin:
        path = Path(todoing_bin).resolve()
        if not path.is_file():
            fail(f"TODOING_BIN is set but does not exist: {todoing_bin}")
        return path, "TODOING_BIN"
    plat, arch, exe = detect_platform_arch()
    portable = CACHE / "portable" / REQUIRED / f"{plat}-{arch}" / f"todoing{exe}"
    if portable.is_file():
        return portable, "portable cache"
    found = shutil.which("todoing")
    if found:
        return Path(found), "PATH"
    fail(
        "no Todoing binary found. Set TODOING_BIN, place a portable build at "
        f"{portable}, or put 'todoing' on PATH."
    )


def reported_version(binary: Path) -> str:
    result = subprocess.run(
        [str(binary), "version"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    return result.stdout.strip() if result.returncode == 0 else "<unavailable>"


def main() -> None:
    binary, source = resolve()
    version = reported_version(binary)
    if version != REQUIRED:
        fail(
            f"incompatible Todoing version: got '{version}', required "
            f"'{REQUIRED}' (source: {source}, binary: {binary})"
        )
    print(binary)


if __name__ == "__main__":
    main()