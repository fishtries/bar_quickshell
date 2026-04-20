#!/usr/bin/env python3
from __future__ import annotations

import configparser
import json
import os
from pathlib import Path


def truthy(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "on"}


def application_dirs() -> list[Path]:
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    data_dirs = [Path(path) for path in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if path]
    extras = [
        Path.home() / ".local/share/flatpak/exports/share",
        Path("/var/lib/flatpak/exports/share"),
    ]

    seen: set[Path] = set()
    result: list[Path] = []

    for base in [data_home, *data_dirs, *extras]:
        app_dir = base / "applications"
        if app_dir.exists() and app_dir not in seen:
            seen.add(app_dir)
            result.append(app_dir)

    return result


def desktop_id(base_dir: Path, file_path: Path) -> str:
    return file_path.relative_to(base_dir).as_posix().replace("/", "-")


def split_field(value: str) -> list[str]:
    return [part.strip() for part in value.split(";") if part.strip()]


def pick_icon_text(categories: list[str], name: str, exec_value: str) -> str:
    haystack = " ".join(categories + [name, exec_value]).lower()

    checks = [
        (["browser", "web", "firefox", "chrome", "zen"], "󰈹"),
        (["terminal", "console", "shell", "kitty", "alacritty"], "󰆍"),
        (["filemanager", "nautilus", "thunar", "dolphin", "files"], "󰉋"),
        (["settings", "control", "preferences", "system"], "󰒓"),
        (["audio", "music", "player"], "󰎆"),
        (["video", "movie", "vlc", "mpv"], "󰕧"),
        (["office", "document", "writer", "calc"], "󰈙"),
        (["network", "internet", "chat", "discord", "telegram"], "󰖟"),
        (["development", "ide", "code", "editor"], "󰨞"),
        (["graphics", "image", "photo", "draw"], "󰋩"),
        (["game", "steam"], "󰊴"),
    ]

    for needles, icon in checks:
        if any(needle in haystack for needle in needles):
            return icon

    return "󰣆"


def pick_alias(app_id: str, name: str) -> str:
    value = app_id.removesuffix(".desktop")
    tail = value.split(".")[-1].split("-")[-1].strip().lower()
    normalized_name = "".join(char for char in name.lower() if char.isalnum())
    if not tail or tail == normalized_name:
        return ""
    return tail[:10]


def parse_desktop_file(base_dir: Path, file_path: Path) -> dict | None:
    parser = configparser.ConfigParser(interpolation=None, strict=False)

    try:
        text = file_path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        text = file_path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None

    try:
        parser.read_string(text)
    except configparser.Error:
        return None

    if not parser.has_section("Desktop Entry"):
        return None

    section = parser["Desktop Entry"]
    if section.get("Type", "Application").strip() != "Application":
        return None
    if truthy(section.get("NoDisplay", "false")):
        return None
    if truthy(section.get("Hidden", "false")):
        return None

    name = section.get("Name", "").strip()
    if not name:
        return None

    app_id = desktop_id(base_dir, file_path)
    generic_name = section.get("GenericName", "").strip()
    comment = section.get("Comment", "").strip()
    exec_value = section.get("Exec", "").strip()
    keywords = split_field(section.get("Keywords", ""))
    categories = split_field(section.get("Categories", ""))

    subtitle = generic_name or comment or exec_value
    alias = pick_alias(app_id, name)

    search_keywords = []
    for value in [generic_name, comment, exec_value, *keywords, *categories, app_id]:
        value = value.strip()
        if value:
            search_keywords.append(value)

    return {
        "section": "Applications",
        "kind": "result",
        "title": name,
        "subtitle": subtitle,
        "iconText": pick_icon_text(categories, name, exec_value),
        "accessoryText": "Launch",
        "accessoryColor": "#55ccff",
        "aliasText": alias,
        "keywords": search_keywords,
        "actionLabel": "Launch",
        "launchType": "desktop",
        "launchValue": app_id,
    }


def main() -> int:
    entries: list[dict] = []
    seen_ids: set[str] = set()

    for base_dir in application_dirs():
        for file_path in sorted(base_dir.rglob("*.desktop")):
            entry = parse_desktop_file(base_dir, file_path)
            if not entry:
                continue
            launch_value = entry["launchValue"]
            if launch_value in seen_ids:
                continue
            seen_ids.add(launch_value)
            entries.append(entry)

    entries.sort(key=lambda entry: (entry["title"].lower(), entry["launchValue"]))

    for entry in entries:
        print(json.dumps(entry, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
