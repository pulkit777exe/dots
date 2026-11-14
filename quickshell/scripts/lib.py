#!/usr/bin/env python3
"""Shared paths + tolerant JSON for the dots Python helpers.

Security: local files only, no network. Importing this module has no
side effects — it only computes XDG paths from the environment.
"""

from __future__ import annotations

import json
import os
from pathlib import Path


def home() -> Path:
    return Path.home()


def config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME", home() / ".config"))


def state_home() -> Path:
    return Path(os.environ.get("XDG_STATE_HOME", home() / ".local" / "state"))


def data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME", home() / ".local" / "share"))


def colors_dir() -> Path:
    return config_home() / "colors"


def candidate_settings_paths() -> list[Path]:
    """Settings files, newest first.

    Quickshell writes per-instance state under by-shell/<id>/, so the most
    recently modified copy wins. The flat path is a fallback for tests and
    older checkouts.
    """
    root = state_home() / "quickshell"
    by_shell = sorted(
        root.glob("by-shell/*/settings.json"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    return [*by_shell, root / "settings.json"]


def load_settings() -> dict:
    for path in candidate_settings_paths():
        data = load_json(path, None)
        if isinstance(data, dict):
            return data
    return {}


def load_json(path: Path, default):
    """Read JSON, returning default on any failure (missing/corrupt)."""
    try:
        data = json.loads(Path(path).read_text())
    except Exception:
        return default
    return data


def hex_to_rgb(h: str):
    h = h.lstrip("#")
    if len(h) == 8:
        h = h[2:]
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    n = int(h, 16)
    return (n >> 16) & 255, (n >> 8) & 255, n & 255
