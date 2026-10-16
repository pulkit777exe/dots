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
