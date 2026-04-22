#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path


SEARCH_TIMEOUT_SECONDS = 1.2
MAX_SEARCH_DEPTH = 6
MAX_SEARCH_THREADS = 1
EXCLUDED_PATTERNS = [
    ".cache",
    ".git",
    "node_modules",
    ".venv",
    "venv",
    "target",
    "dist",
    "build",
    ".cargo",
    ".rustup",
    ".steam",
    "Steam",
    "SteamLibrary",
    ".local/share/Trash",
    ".pnpm-store",
]


def unique_existing_roots(roots: list[Path]) -> list[Path]:
    seen: set[Path] = set()
    result: list[Path] = []

    for root in roots:
        if root.exists() and root not in seen:
            seen.add(root)
            result.append(root)

    return result


def resolve_search(query: str) -> tuple[str, list[Path]]:
    raw = query.strip()

    if raw == "" or raw in {"/", "~"}:
        return "", []

    if raw.startswith("/") or raw.startswith("~"):
        expanded = Path(os.path.expanduser(raw))
        root = expanded.parent
        needle = expanded.name

        while not root.exists() and root != root.parent:
            if root.name:
                needle = f"{root.name} {needle}".strip()
            root = root.parent

        pattern = build_pattern(needle)
        return pattern, unique_existing_roots([root])

    return build_pattern(raw), unique_existing_roots([Path.home()])


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


def run_fd(command: list[str]) -> tuple[int, str]:
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
            timeout=SEARCH_TIMEOUT_SECONDS,
        )
        return completed.returncode, completed.stdout
    except subprocess.TimeoutExpired as error:
        stdout = error.stdout or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode("utf-8", errors="ignore")
        return 0, stdout


def main() -> int:
    query = sys.argv[1] if len(sys.argv) > 1 else ""
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 60
    pattern, roots = resolve_search(query)

    if not pattern or not roots:
        return 0

    command = [
        "fd",
        "--absolute-path",
        "--color",
        "never",
        "--hidden",
        "--max-results",
        str(limit),
        "--threads",
        str(MAX_SEARCH_THREADS),
        "--max-depth",
        str(MAX_SEARCH_DEPTH),
        "-i",
        "-t",
        "f",
        "-t",
        "d",
    ]

    for excluded in EXCLUDED_PATTERNS:
        command.extend(["--exclude", excluded])

    command.extend([
        pattern,
        *[str(root) for root in roots],
    ])

    returncode, stdout = run_fd(command)
    if returncode not in {0, 1}:
        return returncode

    seen: set[str] = set()

    for line in stdout.splitlines():
        candidate = line.strip()
        if not candidate or candidate in seen:
            continue
        seen.add(candidate)
        print(json.dumps(entry_for_path(candidate), ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
