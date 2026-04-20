#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path


def search_roots(query: str) -> list[Path]:
    home = Path.home()
    roots: list[Path] = [home]

    if query.startswith("/"):
        return [Path("/")]

    if len(query.strip()) >= 3:
        roots.extend([
            Path("/etc"),
            Path("/opt"),
            Path("/usr/share"),
        ])

    seen: set[Path] = set()
    result: list[Path] = []

    for root in roots:
        if root.exists() and root not in seen:
            seen.add(root)
            result.append(root)

    return result


def build_pattern(query: str) -> str:
    tokens = [token for token in re.split(r"\s+", query.strip()) if token]
    escaped = [re.escape(token) for token in tokens]
    if not escaped:
        return ""
    return ".*".join(escaped)


def icon_for_path(path: Path, is_dir: bool) -> str:
    if is_dir:
        return "󰉋"

    suffix = path.suffix.lower()
    if suffix in {".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".bmp", ".tiff"}:
        return "󰋩"
    if suffix in {".mp3", ".flac", ".wav", ".ogg", ".m4a"}:
        return "󰎆"
    if suffix in {".mp4", ".mkv", ".webm", ".avi", ".mov"}:
        return "󰕧"
    if suffix in {".pdf", ".doc", ".docx", ".odt", ".md", ".txt", ".rtf"}:
        return "󰈙"
    if suffix in {".zip", ".tar", ".gz", ".xz", ".7z", ".rar"}:
        return "󰗄"
    if suffix in {".py", ".js", ".ts", ".tsx", ".jsx", ".cpp", ".c", ".h", ".hpp", ".rs", ".go", ".java", ".sh", ".nix"}:
        return "󰨞"
    return "󰈔"


def entry_for_path(raw_path: str) -> dict[str, object]:
    path = Path(raw_path)
    is_dir = path.is_dir()
    title = path.name or path.as_posix()
    subtitle = str(path.parent) if path.parent != path else "/"
    extension = path.suffix.lower().lstrip(".")

    keywords = [
        str(path),
        title,
        subtitle,
    ]
    if extension:
        keywords.append(extension)
    keywords.extend(["file", "files", "path", "open", "файл", "папка", "документ", "система"])

    return {
        "section": "Files",
        "kind": "result",
        "title": title,
        "subtitle": subtitle,
        "iconText": icon_for_path(path, is_dir),
        "accessoryText": "Browse" if is_dir else "Open",
        "accessoryColor": "#c6a0ff",
        "aliasText": extension[:8] if extension else ("dir" if is_dir else ""),
        "keywords": keywords,
        "actionLabel": "Open",
        "launchType": "file",
        "launchValue": str(path),
        "launchKey": f"file:{path}",
    }


def main() -> int:
    query = sys.argv[1] if len(sys.argv) > 1 else ""
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 60
    pattern = build_pattern(query)

    if not pattern:
        return 0

    command = [
        "fd",
        "--absolute-path",
        "--color",
        "never",
        "--hidden",
        "--follow",
        "--max-results",
        str(limit),
        "-i",
        "-t",
        "f",
        "-t",
        "d",
        pattern,
        *[str(root) for root in search_roots(query)],
    ]

    completed = subprocess.run(command, capture_output=True, text=True, check=False)
    if completed.returncode not in {0, 1}:
        return completed.returncode

    seen: set[str] = set()

    for line in completed.stdout.splitlines():
        candidate = line.strip()
        if not candidate or candidate in seen:
            continue
        seen.add(candidate)
        print(json.dumps(entry_for_path(candidate), ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
