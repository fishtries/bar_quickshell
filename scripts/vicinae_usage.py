#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from pathlib import Path


USAGE_PATH = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "quickshell" / "data" / "vicinae_usage.json"


def load_usage() -> dict[str, int]:
    try:
        text = USAGE_PATH.read_text(encoding="utf-8").strip()
    except FileNotFoundError:
        return {}
    except OSError:
        return {}

    if not text:
        return {}

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return {}

    if not isinstance(parsed, dict):
        return {}

    result: dict[str, int] = {}
    for key, value in parsed.items():
        if isinstance(key, str) and isinstance(value, int) and value > 0:
            result[key] = value

    return result


def save_usage(data: dict[str, int]) -> None:
    USAGE_PATH.parent.mkdir(parents=True, exist_ok=True)
    temp_path = USAGE_PATH.with_suffix(".tmp")
    temp_path.write_text(json.dumps(data, ensure_ascii=False, sort_keys=True), encoding="utf-8")
    temp_path.replace(USAGE_PATH)


def dump_usage() -> int:
    print(json.dumps(load_usage(), ensure_ascii=False, sort_keys=True))
    return 0


def register_usage(key: str) -> int:
    if not key:
        return 1

    data = load_usage()
    data[key] = data.get(key, 0) + 1
    save_usage(data)
    return 0


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else "dump"

    if command == "dump":
        return dump_usage()
    if command == "register":
        key = sys.argv[2] if len(sys.argv) > 2 else ""
        return register_usage(key)

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
