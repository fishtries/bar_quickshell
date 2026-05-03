#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any


FAVORITES_PATH = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "quickshell" / "data" / "vicinae_favorites.json"
ALLOWED_FIELDS = {
    "section",
    "kind",
    "title",
    "subtitle",
    "iconText",
    "iconName",
    "accessoryText",
    "accessoryColor",
    "aliasText",
    "keywords",
    "actionLabel",
    "launchType",
    "launchValue",
    "launchKey",
    "calcQuestion",
    "calcQuestionUnit",
    "calcAnswer",
    "calcAnswerUnit",
}


def item_key(item: dict[str, Any]) -> str:
    launch_key = item.get("launchKey")
    if isinstance(launch_key, str) and launch_key:
        return launch_key

    launch_type = item.get("launchType")
    launch_value = item.get("launchValue")
    if isinstance(launch_type, str) and isinstance(launch_value, str) and launch_type and launch_value:
        return f"{launch_type}:{launch_value}"

    title = item.get("title")
    if isinstance(title, str) and title:
        return f"title:{title}"

    return ""


def sanitize_item(raw: Any) -> dict[str, Any] | None:
    if not isinstance(raw, dict):
        return None

    item: dict[str, Any] = {}
    for key in ALLOWED_FIELDS:
        value = raw.get(key)
        if isinstance(value, (str, bool, int, float)):
            item[key] = value
        elif key == "keywords" and isinstance(value, list):
            item[key] = [entry for entry in value if isinstance(entry, str)]

    key = item_key(item)
    if not key:
        return None

    item["launchKey"] = key
    return item


def load_favorites() -> list[dict[str, Any]]:
    try:
        text = FAVORITES_PATH.read_text(encoding="utf-8").strip()
    except FileNotFoundError:
        return []
    except OSError:
        return []

    if not text:
        return []

    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return []

    if not isinstance(parsed, list):
        return []

    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    for raw in parsed:
        item = sanitize_item(raw)
        if item is None:
            continue
        key = item_key(item)
        if key in seen:
            continue
        seen.add(key)
        result.append(item)

    return result


def save_favorites(items: list[dict[str, Any]]) -> None:
    FAVORITES_PATH.parent.mkdir(parents=True, exist_ok=True)
    temp_path = FAVORITES_PATH.with_suffix(".tmp")
    temp_path.write_text(json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8")
    temp_path.replace(FAVORITES_PATH)


def dump_favorites() -> int:
    print(json.dumps(load_favorites(), ensure_ascii=False))
    return 0


def toggle_favorite(payload: str) -> int:
    try:
        raw_item = json.loads(payload)
    except json.JSONDecodeError:
        return 1

    item = sanitize_item(raw_item)
    if item is None:
        return 1

    key = item_key(item)
    favorites = load_favorites()
    next_favorites = [entry for entry in favorites if item_key(entry) != key]
    added = len(next_favorites) == len(favorites)

    if added:
        next_favorites.insert(0, item)

    save_favorites(next_favorites)
    print(json.dumps({"added": added, "key": key}, ensure_ascii=False))
    return 0


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else "dump"

    if command == "dump":
        return dump_favorites()
    if command == "toggle":
        payload = sys.argv[2] if len(sys.argv) > 2 else ""
        return toggle_favorite(payload)

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
